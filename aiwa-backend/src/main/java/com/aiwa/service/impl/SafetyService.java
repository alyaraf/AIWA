package com.aiwa.service.impl;

import com.aiwa.dto.request.SafetyEventRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.SafetyEventType;
import com.aiwa.enums.SosDeliveryStatus;
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
    private final SosDeliveryRepository deliveryRepo;

    /** DR-028: SOS texts to trusted contacts per account per day; past this, support is still alerted. */
    static final int MAX_CONTACT_SOS_PER_DAY = 5;
    /** An SOS can be raised during a booking and for this long after it ends. */
    static final java.time.Duration SOS_AFTER_BOOKING = java.time.Duration.ofHours(6);
    /** Attempts per SMS before it is marked FAILED (BE-37). */
    static final int SMS_ATTEMPTS = 3;

    @Value("${aiwa.safety.oncall-phones:}")
    private String onCallPhones;

    /** The push pool (PushExecutorConfig): SMS latency must not hold the SOS request open. */
    @Autowired
    @Qualifier("pushExecutor")
    private Executor smsExecutor;

    /** aiwa_sos_alerts_total for the monitoring alert rule (OPS-5); absent in plain unit tests. */
    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    /**
     * Also publishes the open-SOS backlog (DR-006): how many are open and how old
     * the oldest is, so an alert fires when one sits unanswered.
     */
    @Autowired(required = false)
    void setMeterRegistry(io.micrometer.core.instrument.MeterRegistry registry) {
        this.meterRegistry = registry;
        io.micrometer.core.instrument.Gauge.builder("aiwa.sos.open", this, s -> s.openSosCountSafe())
                .description("Open SOS alerts").register(registry);
        io.micrometer.core.instrument.Gauge.builder("aiwa.sos.open.oldest.age.seconds", this, s -> s.oldestOpenAgeSeconds())
                .description("Age of the oldest open SOS, 0 when none").register(registry);
    }

    double openSosCountSafe() {
        try {
            return safetyRepo.countByTypeAndResolvedFalse(SafetyEventType.SOS);
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    double oldestOpenAgeSeconds() {
        try {
            return safetyRepo.findFirstByTypeAndResolvedFalseOrderByCreatedAtAsc(SafetyEventType.SOS)
                    .map(e -> (double) java.time.Duration.between(e.getCreatedAt(), LocalDateTime.now()).getSeconds())
                    .orElse(0.0);
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    // ── Participant side ─────────────────────────────────────────────────────

    /** Events the requester may see: their own, plus the other party's non-SOS events. */
    @Transactional(readOnly = true)
    public List<ApiResponse.SafetyEventDto> events(Long bookingId, Long userId) {
        loadAuthorizedBooking(bookingId, userId);
        return safetyRepo.findByBookingIdOrderByCreatedAtAsc(bookingId).stream()
                .filter(e -> e.getType() != SafetyEventType.SOS || e.getActor().getId().equals(userId))
                .map(this::toDtoWithDelivery)
                .toList();
    }

    @Transactional
    public ApiResponse.SafetyEventDto record(Long bookingId, Long actorId, SafetyEventRequest request) {
        Booking booking = loadAuthorizedBooking(bookingId, actorId);
        User actor = userRepo.findById(actorId).orElseThrow(() -> new ResourceNotFoundException("User", actorId));
        if (request.getType() == SafetyEventType.SOS) {
            // DR-028: only around a real meeting — during the booking or shortly after.
            requireSosWindow(booking);
            // Pressing SOS again while one is open re-alerts support but doesn't
            // text everyone again (it used to send a full round of SMS each time).
            java.util.Optional<SafetyEvent> open = safetyRepo
                    .findFirstByBookingIdAndActorIdAndTypeAndResolvedFalseOrderByCreatedAtDesc(
                            bookingId, actorId, SafetyEventType.SOS);
            if (open.isPresent()) {
                notifySupport(booking, NotificationType.SAFETY_ALERT,
                        "SOS pressed again — booking #" + booking.getId(), "استغاثة مكررة — الحجز رقم " + booking.getId(),
                        actor.getFullName() + " pressed SOS again" + where(open.get()) + ".",
                        "ضغط " + actor.getFullName() + " زر الاستغاثة مرة أخرى.");
                return toDtoWithDelivery(open.get());
            }
        }
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
        return toDtoWithDelivery(event);
    }

    private void requireSosWindow(Booking booking) {
        switch (booking.getStatus()) {
            case ACCEPTED, ON_THE_WAY, ARRIVED, IN_PROGRESS -> { return; }
            case COMPLETED, NO_SHOW -> {
                LocalDateTime ended = booking.getUpdatedAt() != null ? booking.getUpdatedAt()
                        : LocalDateTime.of(booking.getBookingDate(), booking.getEndTime());
                if (!LocalDateTime.now().isAfter(ended.plus(SOS_AFTER_BOOKING))) return;
            }
            default -> { }
        }
        throw new BusinessException("safety.error.sos_not_live");
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
        java.util.Map<Long, List<SosDelivery>> byEvent = page.isEmpty() ? java.util.Map.of()
                : deliveryRepo.findByEventIdInOrderByIdAsc(page.map(SafetyEvent::getId).toList()).stream()
                        .collect(java.util.stream.Collectors.groupingBy(d -> d.getEvent().getId()));
        return page.map(e -> {
            ApiResponse.AdminSafetyEventDto dto = toAdminDto(e);
            dto.setDeliveries(byEvent.getOrDefault(e.getId(), List.of()).stream()
                    .map(d -> ApiResponse.SosDeliveryDto.builder()
                            .recipientKind(d.getRecipientKind())
                            .phone(d.getPhone())
                            .status(d.getStatus())
                            .attempts(d.getAttempts())
                            .lastError(d.getLastError())
                            .updatedAt(d.getUpdatedAt())
                            .build())
                    .toList());
            return dto;
        });
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

        // 1. The person in trouble: what was done, nothing more (R2-03). Whether
        //    the texts arrived shows on the SOS screen as they are delivered.
        boolean textingContacts = !contactsOf(actor).isEmpty()
                && safetyRepo.countByActorIdAndTypeAndCreatedAtAfter(actor.getId(), SafetyEventType.SOS,
                        LocalDateTime.now().minusDays(1)) <= MAX_CONTACT_SOS_PER_DAY;
        notificationService.send(actor.getId(), NotificationType.SAFETY_ALERT,
                "SOS sent", "تم إرسال الاستغاثة",
                "AIWA support has been alerted" + (textingContacts ? " and we are texting your trusted contacts" : "")
                        + ". If you are in immediate danger call 122 (police).",
                "تم تنبيه دعم AIWA" + (textingContacts ? " وجارٍ إرسال رسالة لجهات الاتصال الموثوقة" : "")
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
        textTracked(event, "ONCALL", supportPhones, supportText);
        if (textingContacts) {
            textTracked(event, "CONTACT", contactsOf(actor).stream().map(TrustedContact::getPhone).toList(), contactText);
        } else if (!contactsOf(actor).isEmpty()) {
            log.warn("SOS on booking #{}: trusted-contact texts skipped (more than {} SOS from this account today)",
                    booking.getId(), MAX_CONTACT_SOS_PER_DAY);
        }
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
     * BE-37: one delivery row per recipient, sent after commit with retries, its
     * state (SENT / FAILED and the error) visible to support in the SOS queue
     * and, as counts, to the user on the SOS screen.
     */
    private void textTracked(SafetyEvent event, String kind, List<String> phones, String text) {
        List<Long> ids = phones.stream().distinct()
                .map(p -> deliveryRepo.save(SosDelivery.builder().event(event).recipientKind(kind)
                        .phone(p.length() > 32 ? p.substring(0, 32) : p).build()).getId())
                .toList();
        if (ids.isEmpty()) return;
        Runnable fanOut = () -> ids.forEach(id -> smsExecutor.execute(() -> deliver(id, text)));
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

    /** Sends one tracked SOS text, retrying with a short back-off. Runs on the push pool, outside any transaction. */
    void deliver(Long deliveryId, String text) {
        SosDelivery d = deliveryRepo.findById(deliveryId).orElse(null);
        if (d == null) return;
        for (int attempt = 1; attempt <= SMS_ATTEMPTS; attempt++) {
            d.setAttempts(attempt);
            try {
                smsService.send(d.getPhone(), text);
                d.setStatus(SosDeliveryStatus.SENT);
                d.setLastError(null);
                deliveryRepo.save(d);
                return;
            } catch (RuntimeException e) {
                String msg = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
                d.setLastError(msg.length() > 255 ? msg.substring(0, 255) : msg);
                log.warn("SOS SMS to {} failed (attempt {}/{}): {}", mask(d.getPhone()), attempt, SMS_ATTEMPTS, msg);
                if (attempt < SMS_ATTEMPTS) sleepQuietly(2000L * attempt);
            }
        }
        d.setStatus(SosDeliveryStatus.FAILED);
        deliveryRepo.save(d);
    }

    /** Test seam: the retry back-off. */
    void sleepQuietly(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
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

    /** The app's view of an SOS: plus whether support was alerted and how the texts are doing (R2-03). */
    private ApiResponse.SafetyEventDto toDtoWithDelivery(SafetyEvent e) {
        ApiResponse.SafetyEventDto dto = toDto(e);
        if (e.getType() != SafetyEventType.SOS || e.getId() == null) return dto;
        List<SosDelivery> deliveries = deliveryRepo.findByEventIdOrderByIdAsc(e.getId());
        List<SosDelivery> contacts = deliveries.stream().filter(d -> "CONTACT".equals(d.getRecipientKind())).toList();
        dto.setContactsTexted((int) contacts.stream().filter(d -> d.getStatus() == SosDeliveryStatus.SENT).count());
        dto.setContactsFailed((int) contacts.stream().filter(d -> d.getStatus() == SosDeliveryStatus.FAILED).count());
        dto.setContactsPending((int) contacts.stream().filter(d -> d.getStatus() == SosDeliveryStatus.PENDING).count());
        // In-app alerts to support admins are written in the same transaction as the SOS.
        dto.setSupportAlerted(supportAdmins().findAny().isPresent()
                || deliveries.stream().anyMatch(d -> "ONCALL".equals(d.getRecipientKind())
                        && d.getStatus() == SosDeliveryStatus.SENT));
        return dto;
    }

    private java.util.stream.Stream<User> supportAdmins() {
        return userRepo.findByRoleAndActive(UserRole.ADMIN, true).stream()
                .filter(a -> a.hasPermission(AdminPermission.SUPPORT) || a.hasPermission(AdminPermission.SUPER_ADMIN));
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
