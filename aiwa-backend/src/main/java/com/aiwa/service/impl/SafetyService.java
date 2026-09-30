package com.aiwa.service.impl;

import com.aiwa.dto.request.SafetyEventRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.SafetyEventType;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ForbiddenException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.SmsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.Executor;

/**
 * Safety events during a booking, and the SOS incident flow (BE-4).
 *
 * <p>An SOS used to notify the customer and the provider — i.e. possibly the
 * very person the user needed protection from — and nobody else. Now it alerts
 * the people who can help: every support admin (in-app + push, bypassing quiet
 * hours), the on-call support phones by SMS, and the user's trusted contacts by
 * SMS. The other party of the booking is deliberately NOT told, and cannot see
 * the SOS in the booking's safety timeline.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SafetyService {

    private final BookingRepository bookingRepo;
    private final SafetyEventRepository safetyRepo;
    private final UserRepository userRepo;
    private final TrustedContactRepository trustedContactRepo;
    private final NotificationServiceImpl notificationService;
    private final SmsService smsService;
    private final AuditService auditService;

    @Value("${aiwa.safety.oncall-phones:}")
    private String onCallPhones;

    /** The push pool (PushExecutorConfig): SMS latency must not hold the SOS request open. */
    @Autowired
    @Qualifier("pushExecutor")
    private Executor smsExecutor;

    /** aiwa_sos_alerts_total for the monitoring alert rule (OPS-5); absent in plain unit tests. */
    @Autowired(required = false)
    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    // ── Participant side ─────────────────────────────────────────────────────

    /** Events the requester may see: their own, plus the other party's non-SOS events. */
    @Transactional(readOnly = true)
    public List<ApiResponse.SafetyEventDto> events(Long bookingId, Long userId) {
        loadAuthorizedBooking(bookingId, userId);
        return safetyRepo.findByBookingIdOrderByCreatedAtAsc(bookingId).stream()
                .filter(e -> e.getType() != SafetyEventType.SOS || e.getActor().getId().equals(userId))
                .map(SafetyService::toDto)
                .toList();
    }

    @Transactional
    public ApiResponse.SafetyEventDto record(Long bookingId, Long actorId, SafetyEventRequest request) {
        Booking booking = loadAuthorizedBooking(bookingId, actorId);
        User actor = userRepo.findById(actorId).orElseThrow(() -> new ResourceNotFoundException("User", actorId));
        SafetyEvent event = safetyRepo.save(SafetyEvent.builder()
                .booking(booking)
                .actor(actor)
                .type(request.getType())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .notes(request.getNotes())
                .build());

        if (request.getType() == SafetyEventType.SOS) {
            raiseSos(booking, actor, event);
            if (meterRegistry != null) meterRegistry.counter("aiwa.sos.alerts").increment();
        }
        return toDto(event);
    }

    /** "I'm safe" — only the person who raised the SOS can close it from the app. */
    @Transactional
    public ApiResponse.SafetyEventDto resolveOwn(Long bookingId, Long eventId, Long userId, String notes) {
        SafetyEvent event = safetyRepo.findByIdAndBookingId(eventId, bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Safety event", eventId));
        if (!event.getActor().getId().equals(userId)) throw new ForbiddenException("error.access_denied");
        if (event.getType() != SafetyEventType.SOS) throw new BusinessException("safety.error.not_sos");
        if (event.isResolved()) return toDto(event);

        User user = event.getActor();
        close(event, user, notes != null && !notes.isBlank() ? notes : "Marked safe by the user");

        notifySupport(event.getBooking(), NotificationType.SAFETY_RESOLVED,
                "SOS closed — user marked safe", "تم إغلاق الاستغاثة — المستخدم بأمان",
                user.getFullName() + " marked themselves safe on booking #" + event.getBooking().getId() + ".",
                user.getFullName() + " أكد أنه بأمان في الحجز رقم " + event.getBooking().getId() + ".");
        String text = user.getFullName() + " marked themselves safe on AIWA. Thank you for standing by.";
        textAfterCommit(contactsOf(user).stream().map(TrustedContact::getPhone).toList(), text);
        return toDto(event);
    }

    // ── Admin side ───────────────────────────────────────────────────────────

    /** @param status OPEN (default), RESOLVED or ALL */
    @Transactional(readOnly = true)
    public Page<ApiResponse.AdminSafetyEventDto> adminQueue(String status, Pageable pageable) {
        String s = status == null ? "OPEN" : status.trim().toUpperCase();
        Page<SafetyEvent> page = switch (s) {
            case "ALL" -> safetyRepo.findByTypeOrderByCreatedAtDesc(SafetyEventType.SOS, pageable);
            case "RESOLVED" -> safetyRepo.findByTypeAndResolvedOrderByCreatedAtDesc(SafetyEventType.SOS, true, pageable);
            case "OPEN" -> safetyRepo.findByTypeAndResolvedOrderByCreatedAtDesc(SafetyEventType.SOS, false, pageable);
            default -> throw new BusinessException("Unknown status: " + status);
        };
        return page.map(SafetyService::toAdminDto);
    }

    @Transactional(readOnly = true)
    public long openSosCount() {
        return safetyRepo.countByTypeAndResolvedFalse(SafetyEventType.SOS);
    }

    @Transactional
    public ApiResponse.AdminSafetyEventDto adminResolve(Long eventId, Long adminId, String notes) {
        SafetyEvent event = safetyRepo.findById(eventId)
                .orElseThrow(() -> new ResourceNotFoundException("Safety event", eventId));
        if (event.getType() != SafetyEventType.SOS) throw new BusinessException("safety.error.not_sos");
        if (notes == null || notes.isBlank()) throw new BusinessException("safety.error.notes_required");
        if (!event.isResolved()) {
            User admin = userRepo.findById(adminId).orElseThrow(() -> new ResourceNotFoundException("User", adminId));
            close(event, admin, notes);
            auditService.record("SOS_RESOLVED", "booking #" + event.getBooking().getId() + " · event #" + eventId);
            notificationService.send(event.getActor().getId(), NotificationType.SAFETY_RESOLVED,
                    "Your safety alert was closed", "تم إغلاق تنبيه الأمان الخاص بك",
                    "AIWA support closed your SOS on booking #" + event.getBooking().getId()
                            + ". Contact support any time if you need help.",
                    "أغلق دعم AIWA تنبيه الاستغاثة للحجز رقم " + event.getBooking().getId()
                            + ". تواصل مع الدعم في أي وقت إذا احتجت المساعدة.",
                    event.getBooking().getId(), event.getBooking().getProvider().getId());
        }
        return toAdminDto(event);
    }

    // ── internals ────────────────────────────────────────────────────────────

    private void raiseSos(Booking booking, User actor, SafetyEvent event) {
        auditService.record("SOS_RAISED", "booking #" + booking.getId() + " · event #" + event.getId());

        // 1. The person in trouble: confirm help is coming.
        notificationService.send(actor.getId(), NotificationType.SAFETY_ALERT,
                "SOS sent", "تم إرسال الاستغاثة",
                "AIWA support has been alerted" + (contactsOf(actor).isEmpty() ? "" : " and your trusted contacts were texted")
                        + ". If you are in immediate danger call 122 (police).",
                "تم تنبيه دعم AIWA" + (contactsOf(actor).isEmpty() ? "" : " وتم إرسال رسالة لجهات الاتصال الموثوقة")
                        + ". إذا كنت في خطر فوري اتصل بـ 122 (الشرطة).",
                booking.getId(), booking.getProvider().getId());

        // 2. Support admins, in-app + push (urgent: ignores quiet hours / mute).
        String role = actor.getId().equals(booking.getCustomer().getId()) ? "customer" : "provider";
        notifySupport(booking, NotificationType.SAFETY_ALERT,
                "SOS — booking #" + booking.getId(), "استغاثة — الحجز رقم " + booking.getId(),
                "The " + role + " " + actor.getFullName() + " pressed SOS" + where(event)
                        + (event.getNotes() != null ? " — \"" + event.getNotes() + "\"" : "") + ".",
                "ضغط " + actor.getFullName() + " زر الاستغاثة في الحجز رقم " + booking.getId() + ".");

        // 3. SMS: on-call support phones and the user's trusted contacts — after
        //    commit, so a rolled-back request never texts anyone.
        String supportText = "AIWA SOS: booking #" + booking.getId() + ", " + role + " " + actor.getFullName()
                + (actor.getPhone() != null ? " (" + actor.getPhone() + ")" : "") + where(event) + ".";
        String contactText = actor.getFullName() + " triggered an SOS on AIWA during a booking" + where(event)
                + ". AIWA support has been alerted. If you can't reach them, call 122.";
        List<String> supportPhones = onCallNumbers();
        textAfterCommit(supportPhones, supportText);
        textAfterCommit(contactsOf(actor).stream().map(TrustedContact::getPhone).toList(), contactText);
        if (supportPhones.isEmpty()) {
            log.warn("SOS on booking #{} — no on-call phone configured (aiwa.safety.oncall-phones)", booking.getId());
        }
    }

    private void close(SafetyEvent event, User by, String notes) {
        event.setResolved(true);
        event.setResolvedAt(LocalDateTime.now());
        event.setResolvedBy(by);
        event.setResolutionNotes(notes.length() > 1000 ? notes.substring(0, 1000) : notes);
        safetyRepo.save(event);
    }

    private void notifySupport(Booking booking, NotificationType type, String titleEn, String titleAr,
                               String bodyEn, String bodyAr) {
        userRepo.findByRoleAndActive(UserRole.ADMIN, true).stream()
                .filter(a -> a.hasPermission(AdminPermission.SUPPORT) || a.hasPermission(AdminPermission.SUPER_ADMIN))
                .forEach(a -> notificationService.send(a.getId(), type, titleEn, titleAr, bodyEn, bodyAr,
                        booking.getId(), booking.getProvider().getId()));
    }

    private List<TrustedContact> contactsOf(User user) {
        return trustedContactRepo.findByUserIdOrderByCreatedAtAsc(user.getId());
    }

    private List<String> onCallNumbers() {
        if (onCallPhones == null || onCallPhones.isBlank()) return List.of();
        return new ArrayList<>(Arrays.stream(onCallPhones.split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).distinct().toList());
    }

    private static String where(SafetyEvent e) {
        return e.getLatitude() != null && e.getLongitude() != null
                ? " at https://maps.google.com/?q=" + e.getLatitude() + "," + e.getLongitude()
                : "";
    }

    /**
     * Texts each number after commit (a rolled-back request never texts anyone),
     * one background task per number: the SOS response doesn't wait on a slow
     * gateway (5 s connect + 10 s read per send), and one failed send doesn't
     * stop the others.
     */
    private void textAfterCommit(List<String> phones, String text) {
        if (phones.isEmpty()) return;
        Runnable fanOut = () -> phones.forEach(phone -> smsExecutor.execute(() -> {
            try {
                smsService.send(phone, text);
            } catch (RuntimeException e) {
                log.warn("Safety SMS to {} failed: {}", mask(phone), e.getMessage());
            }
        }));
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    fanOut.run();
                }
            });
        } else {
            fanOut.run();
        }
    }

    private static String mask(String phone) {
        return phone == null || phone.length() < 4 ? "***" : "***" + phone.substring(phone.length() - 3);
    }

    private Booking loadAuthorizedBooking(Long bookingId, Long userId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean allowed = booking.getCustomer().getId().equals(userId)
                || booking.getProvider().getUser().getId().equals(userId);
        if (!allowed) throw new ForbiddenException("error.access_denied");
        return booking;
    }

    static ApiResponse.SafetyEventDto toDto(SafetyEvent e) {
        return ApiResponse.SafetyEventDto.builder()
                .id(e.getId())
                .bookingId(e.getBooking().getId())
                .actor(ApiResponse.UserDto.builder().id(e.getActor().getId()).fullName(e.getActor().getFullName()).build())
                .type(e.getType())
                .latitude(e.getLatitude())
                .longitude(e.getLongitude())
                .notes(e.getNotes())
                .resolved(e.isResolved())
                .resolvedAt(e.getResolvedAt())
                .resolvedByName(e.getResolvedBy() != null ? e.getResolvedBy().getFullName() : null)
                .resolutionNotes(e.getResolutionNotes())
                .createdAt(e.getCreatedAt())
                .build();
    }

    static ApiResponse.AdminSafetyEventDto toAdminDto(SafetyEvent e) {
        Booking b = e.getBooking();
        User actor = e.getActor();
        boolean byCustomer = Objects.equals(actor.getId(), b.getCustomer().getId());
        return ApiResponse.AdminSafetyEventDto.builder()
                .id(e.getId())
                .bookingId(b.getId())
                .bookingStatus(b.getStatus())
                .homeService(b.isHomeService())
                .address(b.isHomeService() && b.getSavedAddress() != null
                        ? b.getSavedAddress().getAddressLine() : b.getProvider().getAddress())
                .actorId(actor.getId())
                .actorName(actor.getFullName())
                .actorPhone(actor.getPhone())
                .actorRole(byCustomer ? "CUSTOMER" : "PROVIDER")
                .customerName(b.getCustomer().getFullName())
                .customerPhone(b.getCustomer().getPhone())
                .providerName(b.getProvider().getBusinessName())
                .providerPhone(b.getProvider().getUser().getPhone())
                .latitude(e.getLatitude())
                .longitude(e.getLongitude())
                .notes(e.getNotes())
                .resolved(e.isResolved())
                .resolvedAt(e.getResolvedAt())
                .resolvedByName(e.getResolvedBy() != null ? e.getResolvedBy().getFullName() : null)
                .resolutionNotes(e.getResolutionNotes())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
