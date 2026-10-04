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
    /** CR-08: rounds of tries to an on-call phone that ended FAILED (alert rule SosOnCallTextFailed). */
    static final String ONCALL_TEXT_FAILED = "aiwa.sos.oncall.text.failed";

    @Value("${aiwa.safety.oncall-phones:}")
    private String onCallPhones;

    /** CR-08: a text being sent is left alone by the retry sweep for this long. */
    @Value("${aiwa.safety.sos-retry.in-flight-grace:2m}")
    private java.time.Duration inFlightGrace = java.time.Duration.ofMinutes(2);
    /** CR-08: wait after a failed round of tries; doubles each round up to the maximum. */
    @Value("${aiwa.safety.sos-retry.backoff:1m}")
    private java.time.Duration retryBackoff = java.time.Duration.ofMinutes(1);
    @Value("${aiwa.safety.sos-retry.backoff-max:15m}")
    private java.time.Duration retryBackoffMax = java.time.Duration.ofMinutes(15);

    /**
     * SOS texts have their own threads (PushExecutorConfig, CR-08): SMS latency
     * must not hold the SOS request open, and they never wait behind ordinary pushes.
     */
    @Autowired
    @Qualifier("sosExecutor")
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
        // Registered at start-up so the alert's increase() sees the first failure too.
        registry.counter(ONCALL_TEXT_FAILED);
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
                .locationTime(request.getLocationTime())
                .locationAccuracy(request.getLocationAccuracy())
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
            // CR-09 (owner rule 2026-10-04): a cancelled booking keeps the same window, since
            // a cancellation at the door or mid-visit is when someone may need help most.
            case COMPLETED, NO_SHOW, CANCELLED -> {
                LocalDateTime ended = booking.endedAt(); // L-11: not moved by later admin edits
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
        textAfterCommit(contactPhones(user), text);
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
        String role = roleOf(event);
        notifySupport(booking, NotificationType.SAFETY_ALERT,
                "SOS — booking #" + booking.getId(), "استغاثة — الحجز رقم " + booking.getId(),
                "The " + role + " " + actor.getFullName() + " pressed SOS" + where(event)
                        + (event.getNotes() != null ? " — \"" + event.getNotes() + "\"" : "") + ".",
                "ضغط " + actor.getFullName() + " زر الاستغاثة في الحجز رقم " + booking.getId() + ".");

        // 3. SMS: on-call support phones and the user's trusted contacts — after
        //    commit, so a rolled-back request never texts anyone.
        List<String> supportPhones = onCallNumbers();
        textTracked(event, "ONCALL", supportPhones);
        if (textingContacts) {
            textTracked(event, "CONTACT", contactPhones(actor));
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

    /**
     * Trusted contacts' numbers in E.164 (L-13): contacts saved before numbers were
     * normalized can still be in the local 01… form, which the gateway may refuse.
     */
    private List<String> contactPhones(User user) {
        return contactsOf(user).stream().map(TrustedContact::getPhone)
                .map(com.aiwa.util.Identifiers::normalizePhone)
                .filter(java.util.Objects::nonNull).distinct().toList();
    }

    private List<TrustedContact> contactsOf(User user) {
        return trustedContactRepo.findByUserIdOrderByCreatedAtAsc(user.getId());
    }

    private List<String> onCallNumbers() {
        if (onCallPhones == null || onCallPhones.isBlank()) return List.of();
        return new ArrayList<>(Arrays.stream(onCallPhones.split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).distinct().toList());
    }

    private static String roleOf(SafetyEvent e) {
        return e.getActor().getId().equals(e.getBooking().getCustomer().getId()) ? "customer" : "provider";
    }

    /**
     * The SOS text for one kind of recipient. Built from the stored event alone,
     * so the retry sweep can send it again after a restart (CR-08).
     */
    private static String sosText(SafetyEvent event, String kind) {
        User actor = event.getActor();
        if ("ONCALL".equals(kind)) {
            return "AIWA SOS: booking #" + event.getBooking().getId() + ", " + roleOf(event) + " " + actor.getFullName()
                    + (actor.getPhone() != null ? " (" + actor.getPhone() + ")" : "") + where(event) + ".";
        }
        return actor.getFullName() + " triggered an SOS on AIWA during a booking" + where(event)
                + ". AIWA support has been alerted. If you can't reach them, call 122.";
    }

    private static String where(SafetyEvent e) {
        return e.getLatitude() != null && e.getLongitude() != null
                ? " at https://maps.google.com/?q=" + e.getLatitude() + "," + e.getLongitude()
                : "";
    }

    /**
     * BE-37: one delivery row per recipient, sent after commit with retries, its
     * state (SENT / FAILED and the error) visible to support in the SOS queue
     * and, as counts, to the user on the SOS screen. A row that is not SENT is
     * picked up again by {@link #retryDueSosTexts()} (CR-08).
     */
    private void textTracked(SafetyEvent event, String kind, List<String> phones) {
        String text = sosText(event, kind);
        LocalDateTime lease = LocalDateTime.now().plus(inFlightGrace);
        List<Long> ids = phones.stream().distinct()
                .map(p -> deliveryRepo.save(SosDelivery.builder().event(event).recipientKind(kind)
                        .phone(p.length() > 32 ? p.substring(0, 32) : p).nextAttemptAt(lease).build()).getId())
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

    /**
     * CR-08: re-sends every SOS text that is not SENT and is due (never tried
     * because of a restart, or FAILED and past its back-off), for SOS alerts that
     * are still open. Run by SosTextRetryScheduler; a closed SOS is left alone.
     */
    public void retryDueSosTexts() {
        LocalDateTime now = LocalDateTime.now();
        for (SosDelivery d : deliveryRepo.findDueForRetry(now)) {
            String text = sosText(d.getEvent(), d.getRecipientKind());
            // Lease first: the next sweep must not send it again while this one is in flight.
            d.setNextAttemptAt(now.plus(inFlightGrace));
            Long id = deliveryRepo.save(d).getId();
            smsExecutor.execute(() -> deliver(id, text));
        }
    }

    /**
     * Sends one tracked SOS text: a few quick tries, then FAILED with the time of
     * the next round. Runs on the SOS pool, outside any transaction.
     */
    void deliver(Long deliveryId, String text) {
        SosDelivery d = deliveryRepo.findById(deliveryId).orElse(null);
        if (d == null || d.getStatus() == SosDeliveryStatus.SENT) return;
        for (int attempt = 1; attempt <= SMS_ATTEMPTS; attempt++) {
            d.setAttempts(d.getAttempts() + 1);
            try {
                smsService.send(d.getPhone(), text);
                d.setStatus(SosDeliveryStatus.SENT);
                d.setLastError(null);
                d.setNextAttemptAt(null);
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
        d.setNextAttemptAt(LocalDateTime.now().plus(backoffAfter(d.getAttempts() / SMS_ATTEMPTS)));
        deliveryRepo.save(d);
        if ("ONCALL".equals(d.getRecipientKind()) && meterRegistry != null) {
            meterRegistry.counter(ONCALL_TEXT_FAILED).increment();
        }
    }

    /** Back-off after the given number of failed rounds: doubles each round, capped. */
    java.time.Duration backoffAfter(int rounds) {
        java.time.Duration wait = retryBackoff.multipliedBy(1L << Math.min(Math.max(rounds, 1) - 1, 16));
        return wait.compareTo(retryBackoffMax) > 0 ? retryBackoffMax : wait;
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
        // CR-08: true only once a text to an on-call phone was accepted for sending;
        // a support admin account existing is not an alert anyone received.
        dto.setSupportAlerted(deliveries.stream().anyMatch(d -> "ONCALL".equals(d.getRecipientKind())
                && d.getStatus() == SosDeliveryStatus.SENT));
        return dto;
    }

    static ApiResponse.SafetyEventDto toDto(SafetyEvent e) {
        return ApiResponse.SafetyEventDto.builder()
                .id(e.getId())
                .bookingId(e.getBooking().getId())
                .actor(ApiResponse.UserDto.builder().id(e.getActor().getId()).fullName(e.getActor().getFullName()).build())
                .type(e.getType())
                .latitude(e.getLatitude())
                .longitude(e.getLongitude())
                .locationTime(e.getLocationTime())
                .locationAccuracy(e.getLocationAccuracy())
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
                .locationTime(e.getLocationTime())
                .locationAccuracy(e.getLocationAccuracy())
                .notes(e.getNotes())
                .resolved(e.isResolved())
                .resolvedAt(e.getResolvedAt())
                .resolvedByName(e.getResolvedBy() != null ? e.getResolvedBy().getFullName() : null)
                .resolutionNotes(e.getResolutionNotes())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
