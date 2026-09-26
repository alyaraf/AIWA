package com.aiwa.service.impl;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.request.RescheduleRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.BookingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class BookingServiceImpl implements BookingService {

    private final BookingRepository bookingRepo;
    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;
    private final ServiceRepository serviceRepo;
    private final AvailabilityRepository availabilityRepo;
    private final NotificationServiceImpl notificationService;
    private final StaffMemberRepository staffRepo;
    private final SavedAddressRepository savedAddressRepo;
    private final CommissionLedgerRepository commissionLedgerRepo;
    private final PlatformSettingsServiceImpl platformSettings;
    private final RedisRuntimeService redis;

    private static final Duration IDEMPOTENCY_KEY_TTL = Duration.ofMinutes(5);
    private static final Duration AUTO_DEDUP_WINDOW = Duration.ofSeconds(10);

    // ── CREATE ─────────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingDto create(Long customerId, BookingRequest req) {
        return create(customerId, req, null);
    }

    /**
     * @param idempotencyKey Optional client-supplied key (e.g. a UUID generated once
     *                       per tap of "Book"). When present, a retry with the same
     *                       key returns the original booking instead of creating a
     *                       duplicate. When absent — most real double-taps, since the
     *                       mobile client doesn't send one today — the same guard is
     *                       applied automatically, keyed on the booking's own content
     *                       (customer + provider + service + staff + slot) for a short
     *                       window, so an accidental double submit is still caught.
     */
    @Transactional
    public ApiResponse.BookingDto create(Long customerId, BookingRequest req, String idempotencyKey) {
        boolean explicitKey = idempotencyKey != null && !idempotencyKey.isBlank();
        String dedupKey = explicitKey
                ? "idem:booking:" + customerId + ":" + idempotencyKey.trim()
                : "idem:booking:" + customerId + ":auto:" + autoDedupFingerprint(req);
        Duration ttl = explicitKey ? IDEMPOTENCY_KEY_TTL : AUTO_DEDUP_WINDOW;

        // The dedup guard is a convenience, not the primary correctness boundary
        // (the real slot-conflict check below still applies) — if Redis is
        // unreachable, skip it rather than failing every booking attempt outright.
        boolean claimedHere;
        try {
            claimedHere = redis.setIfAbsent(dedupKey, "pending", ttl);
        } catch (RuntimeException e) {
            log.warn("Idempotency check unavailable (Redis down?) — creating without it: {}", e.getMessage());
            return doCreate(customerId, req);
        }

        if (!claimedHere) {
            // Someone already claimed this exact request. If it finished, hand back
            // that booking instead of creating a second one; if it's still in
            // flight, tell the caller rather than silently double-booking.
            String claimed = redis.get(dedupKey).orElse("pending");
            if ("pending".equals(claimed)) {
                throw new BusinessException("booking.error.duplicate");
            }
            try {
                return toDto(bookingRepo.findById(Long.valueOf(claimed))
                        .orElseThrow(() -> new BusinessException("booking.error.duplicate")));
            } catch (NumberFormatException e) {
                throw new BusinessException("booking.error.duplicate");
            }
        }

        try {
            ApiResponse.BookingDto dto = doCreate(customerId, req);
            redis.set(dedupKey, String.valueOf(dto.getId()), IDEMPOTENCY_KEY_TTL);
            return dto;
        } catch (RuntimeException e) {
            // The request was rejected outright (bad input, no slot, etc.) — release
            // the claim so a corrected retry isn't blocked by our own guard.
            redis.delete(dedupKey);
            throw e;
        }
    }

    /** Stable fingerprint for the auto-dedup window — no explicit key required. */
    private String autoDedupFingerprint(BookingRequest req) {
        return String.join("|",
                String.valueOf(req.getProviderId()),
                String.valueOf(req.getServiceId()),
                String.valueOf(req.getStaffMemberId()),
                String.valueOf(req.getBookingType()),
                String.valueOf(req.getBookingDate()),
                String.valueOf(req.getStartTime()));
    }

    private ApiResponse.BookingDto doCreate(Long customerId, BookingRequest req) {
        User customer = userRepo.findById(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("User", customerId));
        ProviderProfile provider = providerRepo.findById(req.getProviderId())
                .orElseThrow(() -> new ResourceNotFoundException("Provider", req.getProviderId()));
        com.aiwa.entity.Service service = serviceRepo.findById(req.getServiceId())
                .orElseThrow(() -> new ResourceNotFoundException("Service", req.getServiceId()));

        if (!service.isActive())
            throw new BusinessException("service.inactive");
        if (!service.getProvider().getId().equals(provider.getId()))
            throw new BusinessException("service.wrong_provider");
        if (provider.getVerificationStatus() != VerificationStatus.APPROVED)
            throw new BusinessException("booking.error.provider_unavailable");
        if (provider.isVacationMode() || provider.isOfflineMode() || provider.isSettlementPaused())
            throw new BusinessException("booking.error.provider_not_accepting");

        StaffMember staffMember = null;
        if (req.getStaffMemberId() != null) {
            staffMember = staffRepo.findByIdAndProviderId(req.getStaffMemberId(), provider.getId())
                    .orElseThrow(() -> new BusinessException("booking.error.staff_wrong_provider"));
            if (!staffMember.isActive()) throw new BusinessException("booking.error.staff_unavailable");
        }

        SavedAddress savedAddress = null;
        if (req.getSavedAddressId() != null) {
            savedAddress = savedAddressRepo.findById(req.getSavedAddressId())
                    .orElseThrow(() -> new ResourceNotFoundException("Saved address", req.getSavedAddressId()));
            if (!savedAddress.getUser().getId().equals(customerId)) {
                throw new BusinessException("booking.error.address_wrong_customer");
            }
        }

        // ── Gap 3: BOOK_NOW — use today + next available slot ─────────────────
        LocalDate bookingDate;
        LocalTime startTime;

        if (req.getBookingType() == BookingType.BOOK_NOW) {
            bookingDate = LocalDate.now();
            startTime   = findNextAvailableSlot(provider.getId(), staffMember, service, bookingDate);
        } else {
            if (req.getBookingDate() == null || req.getStartTime() == null)
                throw new BusinessException("booking.error.date_time_required");
            bookingDate = req.getBookingDate();
            startTime   = req.getStartTime();
        }

        LocalTime endTime = startTime.plusMinutes(service.getDurationMinutes());
        LocalTime blockedEndTime = endTime.plusMinutes(provider.getTravelBufferMinutes() != null
                ? provider.getTravelBufferMinutes() : 0);

        // Conflict is scoped to the chosen staff member's calendar when one is picked,
        // otherwise to the (individual) provider's calendar.
        boolean conflict = staffMember != null
                ? bookingRepo.existsConflictForStaff(staffMember.getId(), bookingDate, startTime, blockedEndTime)
                : bookingRepo.existsConflict(provider.getId(), bookingDate, startTime, blockedEndTime);
        if (conflict) throw new BusinessException("booking.error.conflict");

        // ── Gap 3: calculate ETA for BOOK_NOW ─────────────────────────────────
        Integer eta = (req.getBookingType() == BookingType.BOOK_NOW)
                ? estimateArrivalMinutes(provider) : null;

        // Home-service travel fee: snapshot the provider's current fee onto the
        // booking so later profile edits don't retroactively rewrite this receipt.
        // Null / zero on the provider means "no travel charge" — treat as absent.
        boolean isHomeService = Boolean.TRUE.equals(req.getHomeService());
        java.math.BigDecimal travelFee = null;
        java.math.BigDecimal total = service.getPrice();
        if (isHomeService
                && provider.getHomeServiceTravelFee() != null
                && provider.getHomeServiceTravelFee().signum() > 0) {
            travelFee = provider.getHomeServiceTravelFee();
            total = total.add(travelFee);
        }

        Booking booking = Booking.builder()
                .customer(customer)
                .provider(provider)
                .service(service)
                .staffMember(staffMember)
                .savedAddress(savedAddress)
                .bookingDate(bookingDate)
                .startTime(startTime)
                .endTime(endTime)
                .bookingType(req.getBookingType())
                .estimatedArrivalMinutes(eta)
                .homeService(isHomeService)
                .status(BookingStatus.PENDING)
                .totalPrice(total)
                .travelFee(travelFee)
                .notes(req.getNotes())
                .paymentStatus(PaymentStatus.CASH_PENDING)
                .paymentMethod(req.getPaymentMethod() != null ? req.getPaymentMethod() : "CASH")
                .build();

        Booking saved = bookingRepo.save(booking);

        // Notify provider (req 6)
        notificationService.send(
                provider.getUser().getId(),
                NotificationType.BOOKING_CREATED,
                "New booking received",
                "حجز جديد",
                customer.getFullName() + " booked " + service.getName() + " on " + bookingDate,
                customer.getFullName() + " حجز " + service.getName() + " في " + bookingDate,
                saved.getId(), provider.getId()
        );

        return toDto(saved);
    }

    // ── READ ───────────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.BookingDto getById(Long bookingId, Long requesterId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean isOwner = booking.getCustomer().getId().equals(requesterId)
                || booking.getProvider().getUser().getId().equals(requesterId);
        if (!isOwner) throw new BusinessException("error.access_denied");
        return toDto(booking);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getMyBookings(Long customerId, Pageable pageable) {
        return bookingRepo.findByCustomerIdOrderByCreatedAtDesc(customerId, pageable).map(this::toDto);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getProviderBookings(Long userId, Pageable pageable) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        return bookingRepo.findByProviderIdOrderByBookingDateAscStartTimeAsc(profile.getId(), pageable)
                .map(this::toDto);
    }

    // ── STATUS UPDATE ──────────────────────────────────────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingDto updateStatus(Long userId, Long bookingId, BookingStatus newStatus) {
        // Completion carries a payment outcome — route it through the dedicated
        // method so cash-confirmed vs disputed and commission stay consistent.
        if (newStatus == BookingStatus.COMPLETED) {
            return complete(userId, bookingId, true);
        }
        // EXPIRED is a system-only transition driven by the expiry scheduler.
        if (newStatus == BookingStatus.EXPIRED) {
            throw new BusinessException("booking.error.expired_is_automatic");
        }

        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        boolean isProvider = booking.getProvider().getUser().getId().equals(userId);
        boolean isCustomer = booking.getCustomer().getId().equals(userId);

        // Gap 8: transition guard
        if (!booking.getStatus().canTransitionTo(newStatus)) {
            throw new BusinessException("Cannot change status from "
                    + booking.getStatus() + " to " + newStatus);
        }

        // Role-based permission
        if (newStatus == BookingStatus.CANCELLED) {
            if (!isCustomer && !isProvider) throw new BusinessException("error.not_authorized");
            if (isCustomer) enforceCustomerCancellationCutoff(booking);
            booking.setCancelledBy(isCustomer ? "CUSTOMER" : "PROVIDER");
            booking.setCancelledAt(LocalDateTime.now());
            if (isProvider) {
                ProviderProfile provider = booking.getProvider();
                provider.setCancellationStrikes(provider.getCancellationStrikes() + 1);
                providerRepo.save(provider);
                booking.setPenaltyApplied(true); // provider cancel after accept incurs a penalty
            }
        }

        if (newStatus == BookingStatus.NO_SHOW) {
            booking.setPenaltyApplied(true);
        }

        if ((newStatus == BookingStatus.ACCEPTED
                || newStatus == BookingStatus.ON_THE_WAY
                || newStatus == BookingStatus.ARRIVED
                || newStatus == BookingStatus.IN_PROGRESS
                || newStatus == BookingStatus.COMPLETED
                || newStatus == BookingStatus.NO_SHOW) && !isProvider) {
            throw new BusinessException("booking.error.only_provider_update_status");
        }

        booking.setStatus(newStatus);
        bookingRepo.save(booking);

        // Notify customer (req 6)
        sendStatusNotification(booking, newStatus);

        return toDto(booking);
    }

    // ── COMPLETE + payment outcome (cash vs disputed) ──────────────────────────

    /**
     * Provider marks a booking COMPLETED. When cash was collected the booking is
     * CASH_CONFIRMED and platform commission is recorded; otherwise it is flagged
     * DISPUTED, admins are notified, and no commission is charged.
     */
    @Transactional
    public ApiResponse.BookingDto complete(Long userId, Long bookingId, boolean cashCollected) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(userId))
            throw new BusinessException("booking.error.only_provider_complete");
        if (!booking.getStatus().canTransitionTo(BookingStatus.COMPLETED))
            throw new BusinessException("Cannot complete booking in status: " + booking.getStatus());

        booking.setStatus(BookingStatus.COMPLETED);

        if (cashCollected) {
            booking.setPaymentStatus(PaymentStatus.CASH_CONFIRMED);
            bookingRepo.save(booking);
            recordCommissionIfNeeded(booking);
        } else {
            booking.setPaymentStatus(PaymentStatus.DISPUTED);
            bookingRepo.save(booking);
            notifyAdminsOfDispute(booking);
        }

        sendStatusNotification(booking, BookingStatus.COMPLETED);
        return toDto(booking);
    }

    /** Admin override: force-cancel any non-terminal booking. */
    @Transactional
    public ApiResponse.BookingDto adminForceCancel(Long bookingId, String reason) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (booking.getStatus().isSlotReleasing()
                || booking.getStatus() == BookingStatus.COMPLETED
                || booking.getStatus() == BookingStatus.NO_SHOW) {
            throw new BusinessException("Booking is already closed (" + booking.getStatus() + ")");
        }

        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledBy("ADMIN");
        booking.setCancellationReason(reason != null && !reason.isBlank() ? reason : "Cancelled by admin");
        booking.setCancelledAt(LocalDateTime.now());
        bookingRepo.save(booking);

        sendStatusNotification(booking, BookingStatus.CANCELLED);
        notificationService.send(
                booking.getProvider().getUser().getId(),
                NotificationType.BOOKING_CANCELLED,
                "Booking cancelled by admin",
                "تم إلغاء الحجز من قبل الإدارة",
                "Booking #" + booking.getId() + " was cancelled by an administrator.",
                "تم إلغاء الحجز رقم " + booking.getId() + " من قبل الإدارة.",
                booking.getId(), booking.getProvider().getId()
        );
        return toDto(booking);
    }

    /** Admin resolves a DISPUTED payment: confirm cash (+commission) or write it off. */
    @Transactional
    public ApiResponse.BookingDto adminResolveDispute(Long bookingId, boolean paid) {
        return adminResolveDispute(bookingId, paid ? "PAID" : "UNPAID");
    }

    /**
     * Admin resolves a DISPUTED payment. Outcome:
     *  PAID    — cash confirmed, commission charged
     *  UNPAID  — written off, no commission
     *  NO_SHOW — no-show recorded + penalty, no commission
     *  CANCEL  — booking voided entirely
     */
    @Transactional
    public ApiResponse.BookingDto adminResolveDispute(Long bookingId, String outcome) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        if (booking.getPaymentStatus() != PaymentStatus.DISPUTED) {
            throw new BusinessException("booking.error.not_disputed");
        }
        String choice = outcome == null ? "" : outcome.trim().toUpperCase();

        String summaryEn;
        switch (choice) {
            case "PAID" -> {
                booking.setPaymentStatus(PaymentStatus.CASH_CONFIRMED);
                bookingRepo.save(booking);
                recordCommissionIfNeeded(booking);
                summaryEn = "paid";
            }
            case "UNPAID" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                bookingRepo.save(booking);
                summaryEn = "written off (unpaid)";
            }
            case "NO_SHOW" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                booking.setStatus(BookingStatus.NO_SHOW);
                booking.setPenaltyApplied(true);
                bookingRepo.save(booking);
                summaryEn = "no-show recorded";
            }
            case "CANCEL" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                booking.setStatus(BookingStatus.CANCELLED);
                booking.setCancelledBy("ADMIN");
                booking.setCancellationReason("Voided during dispute resolution");
                booking.setCancelledAt(LocalDateTime.now());
                bookingRepo.save(booking);
                summaryEn = "booking cancelled";
            }
            default -> throw new BusinessException("Unknown dispute outcome: " + outcome);
        }

        notificationService.send(
                booking.getProvider().getUser().getId(),
                choice.equals("PAID") ? NotificationType.PAYMENT_CONFIRMED : NotificationType.PAYMENT_DISPUTED,
                "Dispute resolved",
                "تم حل النزاع",
                "Booking #" + booking.getId() + " dispute resolved as " + summaryEn + ".",
                "تم حل نزاع الحجز رقم " + booking.getId() + ".",
                booking.getId(), booking.getProvider().getId()
        );
        return toDto(booking);
    }

    /** Customer checks in at an on-site/venue booking so the provider can begin. */
    @Transactional
    public ApiResponse.BookingDto checkIn(Long customerId, Long bookingId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_checkin");
        if (booking.isHomeService())
            throw new BusinessException("booking.error.checkin_onsite_only");
        if (booking.getStatus() != BookingStatus.ACCEPTED)
            throw new BusinessException("booking.error.checkin_requires_accepted");
        if (booking.getCheckedInAt() != null)
            throw new BusinessException("booking.error.already_checked_in");

        booking.setCheckedInAt(LocalDateTime.now());
        bookingRepo.save(booking);

        notificationService.send(
                booking.getProvider().getUser().getId(),
                NotificationType.BOOKING_REMINDER,
                "Customer checked in",
                "قام العميل بتسجيل الوصول",
                booking.getCustomer().getFullName() + " has checked in for " + booking.getService().getName(),
                booking.getCustomer().getFullName() + " سجّل الوصول لـ " + booking.getService().getName(),
                booking.getId(), booking.getProvider().getId()
        );
        return toDto(booking);
    }

    /**
     * Customer confirms cash was paid, or reports it unpaid/disputed, after the
     * provider has completed the service.
     */
    @Transactional
    public ApiResponse.BookingDto confirmPayment(Long customerId, Long bookingId, boolean paid) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_confirm_payment");
        if (booking.getStatus() != BookingStatus.COMPLETED)
            throw new BusinessException("booking.error.payment_confirm_requires_completed");

        if (paid) {
            booking.setPaymentStatus(PaymentStatus.CASH_CONFIRMED);
            bookingRepo.save(booking);
            recordCommissionIfNeeded(booking); // idempotent

            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.PAYMENT_CONFIRMED,
                    "Cash payment confirmed",
                    "تم تأكيد الدفع النقدي",
                    booking.getCustomer().getFullName() + " confirmed cash payment for booking #" + booking.getId(),
                    booking.getCustomer().getFullName() + " أكد الدفع النقدي للحجز رقم " + booking.getId(),
                    booking.getId(), booking.getProvider().getId()
            );
        } else {
            booking.setPaymentStatus(PaymentStatus.DISPUTED);
            bookingRepo.save(booking);
            notifyAdminsOfDispute(booking);

            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.PAYMENT_DISPUTED,
                    "Payment reported unpaid / disputed",
                    "تم الإبلاغ عن عدم الدفع / نزاع",
                    booking.getCustomer().getFullName() + " reported booking #" + booking.getId() + " as unpaid/disputed",
                    booking.getCustomer().getFullName() + " أبلغ عن الحجز رقم " + booking.getId() + " كغير مدفوع/متنازع عليه",
                    booking.getId(), booking.getProvider().getId()
            );
        }
        return toDto(booking);
    }

    private void notifyAdminsOfDispute(Booking booking) {
        userRepo.findByRoleAndActive(UserRole.ADMIN, true).forEach(admin ->
                notificationService.send(
                        admin.getId(),
                        NotificationType.PAYMENT_DISPUTED,
                        "Payment disputed / unpaid",
                        "نزاع على الدفع / غير مدفوع",
                        "Booking #" + booking.getId() + " was completed but cash was not confirmed.",
                        "تم إكمال الحجز رقم " + booking.getId() + " لكن لم يتم تأكيد الدفع النقدي.",
                        booking.getId(), booking.getProvider().getId()
                ));
    }

    // ── EXPIRY (system) ────────────────────────────────────────────────────────

    /** Expire PENDING requests the provider never answered within the response window. */
    @Transactional
    public int expireStalePendingBookings() {
        // Each provider may set its own response window, so filter per booking
        // rather than with a single cutoff.
        LocalDateTime now = LocalDateTime.now();
        List<Booking> stale = bookingRepo.findByStatus(BookingStatus.PENDING).stream()
                .filter(b -> b.getCreatedAt() != null)
                .filter(b -> b.getCreatedAt().isBefore(
                        now.minusMinutes(platformSettings.getResponseWindowMinutes(b.getProvider()))))
                .toList();

        for (Booking booking : stale) {
            booking.setStatus(BookingStatus.EXPIRED);
            bookingRepo.save(booking);

            notificationService.send(
                    booking.getCustomer().getId(),
                    NotificationType.BOOKING_EXPIRED,
                    "Booking request expired",
                    "انتهت صلاحية طلب الحجز",
                    "Your request for " + booking.getService().getName()
                            + " expired because the provider did not respond in time.",
                    "انتهت صلاحية طلبك لـ " + booking.getService().getName()
                            + " لأن المزود لم يرد في الوقت المحدد.",
                    booking.getId(), booking.getProvider().getId()
            );
            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.BOOKING_EXPIRED,
                    "Booking request expired",
                    "انتهت صلاحية طلب الحجز",
                    "A booking request for " + booking.getService().getName()
                            + " expired because it was not answered in time.",
                    "انتهت صلاحية طلب حجز لـ " + booking.getService().getName()
                            + " لعدم الرد عليه في الوقت المحدد.",
                    booking.getId(), booking.getProvider().getId()
            );
        }
        return stale.size();
    }

    // ── PROVIDER PROPOSES ALTERNATIVE TIME (customer accept/decline) ───────────

    /** Provider proposes an alternative slot for a PENDING booking. */
    @Transactional
    public ApiResponse.BookingDto proposeReschedule(Long providerUserId, Long bookingId, RescheduleRequest req) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(providerUserId))
            throw new BusinessException("booking.error.only_provider_propose");
        if (booking.getStatus() != BookingStatus.PENDING)
            throw new BusinessException("booking.error.propose_requires_pending");

        LocalTime newEnd = req.getStartTime().plusMinutes(booking.getService().getDurationMinutes());
        if (bookingRepo.existsConflict(booking.getProvider().getId(),
                req.getBookingDate(), req.getStartTime(), newEnd))
            throw new BusinessException("booking.error.conflict");

        booking.setProposedDate(req.getBookingDate());
        booking.setProposedStartTime(req.getStartTime());
        bookingRepo.save(booking);

        notificationService.send(
                booking.getCustomer().getId(),
                NotificationType.BOOKING_TIME_PROPOSED,
                "Provider proposed a new time",
                "اقترح المزود وقتاً جديداً",
                "The provider proposed " + req.getBookingDate() + " at " + req.getStartTime()
                        + " for " + booking.getService().getName() + ". Accept or decline.",
                "اقترح المزود " + req.getBookingDate() + " في " + req.getStartTime()
                        + " لـ " + booking.getService().getName() + ". اقبل أو ارفض.",
                booking.getId(), booking.getProvider().getId()
        );
        return toDto(booking);
    }

    /** Customer accepts or declines a provider-proposed alternative slot. */
    @Transactional
    public ApiResponse.BookingDto respondToProposal(Long customerId, Long bookingId, boolean accept) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_respond_proposal");
        if (booking.getProposedDate() == null || booking.getProposedStartTime() == null)
            throw new BusinessException("booking.error.no_proposal");
        if (booking.getStatus() != BookingStatus.PENDING)
            throw new BusinessException("booking.error.not_awaiting_confirmation");

        if (accept) {
            LocalDate d = booking.getProposedDate();
            LocalTime s = booking.getProposedStartTime();
            LocalTime e = s.plusMinutes(booking.getService().getDurationMinutes());
            if (bookingRepo.existsConflict(booking.getProvider().getId(), d, s, e))
                throw new BusinessException("booking.error.conflict");

            booking.setBookingDate(d);
            booking.setStartTime(s);
            booking.setEndTime(e);
            booking.setStatus(BookingStatus.ACCEPTED);
            booking.setProposedDate(null);
            booking.setProposedStartTime(null);
            bookingRepo.save(booking);

            sendStatusNotification(booking, BookingStatus.ACCEPTED);
            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.BOOKING_CONFIRMED,
                    "Proposed time accepted",
                    "تم قبول الوقت المقترح",
                    booking.getCustomer().getFullName() + " accepted the proposed time.",
                    booking.getCustomer().getFullName() + " قبل الوقت المقترح.",
                    booking.getId(), booking.getProvider().getId()
            );
        } else {
            booking.setStatus(BookingStatus.REJECTED);
            booking.setRejectionReason("Customer declined the proposed time");
            booking.setCancelledAt(LocalDateTime.now());
            booking.setCancelledBy("CUSTOMER");
            booking.setProposedDate(null);
            booking.setProposedStartTime(null);
            bookingRepo.save(booking);

            notificationService.send(
                    booking.getProvider().getUser().getId(),
                    NotificationType.BOOKING_REJECTED,
                    "Proposed time declined",
                    "تم رفض الوقت المقترح",
                    booking.getCustomer().getFullName() + " declined the proposed time.",
                    booking.getCustomer().getFullName() + " رفض الوقت المقترح.",
                    booking.getId(), booking.getProvider().getId()
            );
        }
        return toDto(booking);
    }

    // ── Gap 4: REJECT with reason + return alternatives ────────────────────────

    @Transactional
    public ApiResponse.BookingWithAlternativesDto rejectWithAlternatives(
            Long userId, Long bookingId, String reason) {

        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(userId))
            throw new BusinessException("error.not_authorized");
        if (!booking.getStatus().canTransitionTo(BookingStatus.REJECTED))
            throw new BusinessException("Cannot reject booking in status: " + booking.getStatus());

        booking.setStatus(BookingStatus.REJECTED);
        booking.setRejectionReason(reason);
        booking.setCancelledAt(LocalDateTime.now());
        booking.setCancelledBy("PROVIDER");
        bookingRepo.save(booking);

        notificationService.send(
                booking.getCustomer().getId(),
                NotificationType.BOOKING_REJECTED,
                "Booking rejected",
                "تم رفض الحجز",
                "Your booking was rejected. Reason: " + reason,
                "تم رفض حجزك. السبب: " + reason,
                booking.getId(), booking.getProvider().getId()
        );

        // Gap 4: suggest alternatives
        List<ApiResponse.ProviderSummaryDto> alternatives =
                findAlternativeProviders(booking.getProvider(), booking.getService());

        return ApiResponse.BookingWithAlternativesDto.builder()
                .booking(toDto(booking))
                .alternativeProviders(alternatives)
                .build();
    }

    // ── AVAILABLE SLOTS ────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public List<ApiResponse.TimeSlotDto> getAvailableSlots(Long providerId, Long serviceId,
                                                           Long staffMemberId, LocalDate date) {
        com.aiwa.entity.Service service = serviceRepo.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));

        DayOfWeek dow = date.getDayOfWeek();
        com.aiwa.entity.Availability avail = resolveAvailability(providerId, staffMemberId, dow);

        if (avail == null || !avail.isAvailable()) return Collections.emptyList();

        // Scope existing bookings to the chosen staff member's calendar when picked.
        List<Booking> existing = staffMemberId != null
                ? bookingRepo.findByStaffMemberIdAndBookingDate(staffMemberId, date)
                : bookingRepo.findByProviderIdAndBookingDate(providerId, date);
        List<ApiResponse.TimeSlotDto> slots = new ArrayList<>();
        LocalTime cursor = avail.getStartTime();
        int duration = service.getDurationMinutes();

        while (!cursor.plusMinutes(duration).isAfter(avail.getEndTime())) {
            final LocalTime slotStart = cursor;
            final LocalTime slotEnd   = cursor.plusMinutes(duration);
            final LocalTime blockedSlotEnd = slotEnd.plusMinutes(
                    service.getProvider().getTravelBufferMinutes() != null
                            ? service.getProvider().getTravelBufferMinutes() : 0);
            boolean taken = existing.stream()
                    .filter(b -> !b.getStatus().isSlotReleasing())
                    .anyMatch(b -> b.getStartTime().isBefore(blockedSlotEnd)
                               && b.getEndTime().isAfter(slotStart));

            slots.add(ApiResponse.TimeSlotDto.builder()
                    .startTime(slotStart).endTime(slotEnd).booked(taken).build());
            cursor = cursor.plusMinutes(avail.getSlotDurationMinutes());
        }
        return slots;
    }

    // ── HELPERS ────────────────────────────────────────────────────────────────

    /**
     * Resolve the applicable availability for a day: a staff member's own row when
     * present, otherwise the provider-level row (fallback for shops without per-staff
     * hours, and the normal case for individuals).
     */
    private com.aiwa.entity.Availability resolveAvailability(Long providerId, Long staffMemberId, DayOfWeek dow) {
        if (staffMemberId != null) {
            com.aiwa.entity.Availability staffAvail = availabilityRepo
                    .findByProviderIdAndStaffMemberIdAndDayOfWeek(providerId, staffMemberId, dow)
                    .orElse(null);
            if (staffAvail != null) return staffAvail;
        }
        return availabilityRepo.findByProviderIdAndStaffMemberIsNullAndDayOfWeek(providerId, dow)
                .orElseGet(() -> availabilityRepo.findByProviderIdAndDayOfWeek(providerId, dow).orElse(null));
    }

    /** Gap 3: find the next free slot starting from now */
    private LocalTime findNextAvailableSlot(Long providerId,
                                             StaffMember staff,
                                             com.aiwa.entity.Service service,
                                             LocalDate date) {
        DayOfWeek dow = date.getDayOfWeek();
        Long staffId = staff != null ? staff.getId() : null;
        com.aiwa.entity.Availability avail = resolveAvailability(providerId, staffId, dow);

        if (avail == null || !avail.isAvailable())
            throw new BusinessException("booking.error.provider_unavailable_today");

        List<Booking> existing = staffId != null
                ? bookingRepo.findByStaffMemberIdAndBookingDate(staffId, date)
                : bookingRepo.findByProviderIdAndBookingDate(providerId, date);
        LocalTime cursor = LocalTime.now().isAfter(avail.getStartTime())
                ? LocalTime.now().plusMinutes(5)
                : avail.getStartTime();

        // round up to next slot boundary
        int slot = avail.getSlotDurationMinutes();
        int mins = cursor.getHour() * 60 + cursor.getMinute();
        mins = ((mins + slot - 1) / slot) * slot;
        cursor = LocalTime.of(mins / 60, mins % 60);

        int duration = service.getDurationMinutes();
        while (!cursor.plusMinutes(duration).isAfter(avail.getEndTime())) {
            final LocalTime s = cursor;
            final LocalTime e = cursor.plusMinutes(duration);
            boolean taken = existing.stream()
                    .filter(b -> !b.getStatus().isSlotReleasing())
                    .anyMatch(b -> b.getStartTime().isBefore(e) && b.getEndTime().isAfter(s));
            if (!taken) return s;
            cursor = cursor.plusMinutes(slot);
        }
        throw new BusinessException("booking.error.no_book_now_slots");
    }

    /** Gap 3: simple ETA estimate (can be replaced with Google Maps Distance API later) */
    private Integer estimateArrivalMinutes(ProviderProfile provider) {
        // Placeholder: 20–40 min random estimate
        // In production: use Google Maps Distance Matrix API with customer's location
        return 20 + (int)(Math.random() * 20);
    }

    private void recordCommissionIfNeeded(Booking booking) {
        if (commissionLedgerRepo.existsByBookingId(booking.getId())) return;
        // Rate is the admin-editable platform setting at completion time; snapshotted
        // onto the ledger entry so historical entries keep the rate they were charged.
        java.math.BigDecimal pct = platformSettings.getCommissionPercentFor(booking.getProvider());
        // Commission is charged on the *service* portion only. Any home-service
        // travel fee is pass-through — the provider is paying Uber out of it, the
        // platform doesn't skim it. Ledger's bookingAmount still records the true
        // total the customer paid, so the reader can see the breakdown against
        // the booking's own travelFee field.
        java.math.BigDecimal commissionBase = booking.getTotalPrice();
        if (booking.getTravelFee() != null) {
            commissionBase = commissionBase.subtract(booking.getTravelFee());
        }
        java.math.BigDecimal commissionAmount = commissionBase
                .multiply(pct)
                .divide(java.math.BigDecimal.valueOf(100), 2, java.math.RoundingMode.HALF_UP);
        commissionLedgerRepo.save(CommissionLedgerEntry.builder()
                .provider(booking.getProvider())
                .booking(booking)
                .bookingAmount(booking.getTotalPrice())
                .commissionPercent(pct)
                .commissionAmount(commissionAmount)
                .status(LedgerEntryStatus.DUE)
                .build());
        booking.setCommissionAmount(commissionAmount);
        bookingRepo.save(booking);
        notificationService.send(
                booking.getProvider().getUser().getId(),
                NotificationType.COMMISSION_DUE,
                "Commission due",
                "عمولة مستحقة",
                "A commission entry was added for booking #" + booking.getId(),
                "تمت إضافة عمولة للحجز رقم " + booking.getId(),
                booking.getId(), booking.getProvider().getId()
        );
    }

    private void enforceCustomerCancellationCutoff(Booking booking) {
        LocalDateTime appointment = LocalDateTime.of(booking.getBookingDate(), booking.getStartTime());
        int cutoffHours = platformSettings.getCancellationCutoffHours(booking.getProvider());
        if (LocalDateTime.now().isAfter(appointment.minusHours(cutoffHours))) {
            throw new BusinessException(
                "Cancellation deadline passed. Must cancel at least "
                + cutoffHours + " hours before the appointment.");
        }
    }

    /** Gap 4: find alternative approved providers for the same service category */
    private List<ApiResponse.ProviderSummaryDto> findAlternativeProviders(
            ProviderProfile rejected, com.aiwa.entity.Service service) {

        return providerRepo.findNearby(
                    rejected.getLatitude() != null ? rejected.getLatitude() : 0,
                    rejected.getLongitude() != null ? rejected.getLongitude() : 0,
                    15.0)
                .stream()
                .filter(p -> !p.getId().equals(rejected.getId()))
                .filter(p -> p.getVerificationStatus() == VerificationStatus.APPROVED)
                .filter(p -> p.getPrimaryCategory() == service.getCategory()
                          || p.getServices().stream().anyMatch(
                                s -> s.isActive() && s.getCategory() == service.getCategory()))
                .limit(3)
                .map(p -> ApiResponse.ProviderSummaryDto.builder()
                        .id(p.getId())
                        .businessName(p.getBusinessName())
                        .address(p.getAddress())
                        .averageRating(p.getAverageRating())
                        .primaryCategory(p.getPrimaryCategory())
                        .verificationStatus(p.getVerificationStatus())
                        .build())
                .collect(Collectors.toList());
    }

    // ── RESCHEDULE ─────────────────────────────────────────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingDto reschedule(Long customerId, Long bookingId, RescheduleRequest req) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_reschedule");

        if (booking.getStatus() != BookingStatus.PENDING && booking.getStatus() != BookingStatus.ACCEPTED)
            throw new BusinessException("booking.error.reschedule_requires_pending_or_accepted");

        LocalDate newDate  = req.getBookingDate();
        LocalTime newStart = req.getStartTime();
        LocalTime newEnd   = newStart.plusMinutes(booking.getService().getDurationMinutes());

        boolean conflict = bookingRepo.existsConflict(
                booking.getProvider().getId(), newDate, newStart, newEnd);
        if (conflict) throw new BusinessException("booking.error.conflict");

        booking.setBookingDate(newDate);
        booking.setStartTime(newStart);
        booking.setEndTime(newEnd);
        // Reset to PENDING so provider can re-confirm the new time
        booking.setStatus(BookingStatus.PENDING);
        bookingRepo.save(booking);

        notificationService.send(
                booking.getProvider().getUser().getId(),
                NotificationType.BOOKING_CREATED,
                "Booking rescheduled",
                "تم إعادة جدولة الحجز",
                booking.getCustomer().getFullName() + " rescheduled to " + newDate + " at " + newStart,
                booking.getCustomer().getFullName() + " أعاد الجدولة إلى " + newDate + " في " + newStart,
                booking.getId(), booking.getProvider().getId()
        );

        return toDto(booking);
    }

    private void sendStatusNotification(Booking booking, BookingStatus newStatus) {
        NotificationType type = switch (newStatus) {
            case ACCEPTED    -> NotificationType.BOOKING_CONFIRMED;
            case CANCELLED   -> NotificationType.BOOKING_CANCELLED;
            case COMPLETED   -> NotificationType.BOOKING_COMPLETED;
            case REJECTED    -> NotificationType.BOOKING_REJECTED;
            default          -> null;
        };
        if (type == null) return;

        notificationService.send(
                booking.getCustomer().getId(), type,
                "Booking " + newStatus.name().toLowerCase(),
                "تم تحديث الحجز",
                "Your booking for " + booking.getService().getName()
                        + " is now " + newStatus.name().toLowerCase(),
                "تم تحديث حجزك لـ " + booking.getService().getName(),
                booking.getId(), booking.getProvider().getId()
        );
    }

    // ── MAPPER ────────────────────────────────────────────────────────────────

    private ApiResponse.BookingDto toDto(Booking b) {
        return ApiResponse.BookingDto.builder()
                .id(b.getId())
                .customer(toUserDto(b.getCustomer()))
                .provider(toProviderSummary(b.getProvider()))
                .service(toServiceDto(b.getService()))
                .bookingDate(b.getBookingDate())
                .startTime(b.getStartTime())
                .endTime(b.getEndTime())
                .bookingType(b.getBookingType())
                .estimatedArrivalMinutes(b.getEstimatedArrivalMinutes())
                .staffMember(b.getStaffMember() != null ? toStaffDto(b.getStaffMember()) : null)
                .savedAddress(b.getSavedAddress() != null ? toAddressDto(b.getSavedAddress()) : null)
                .homeService(b.isHomeService())
                .status(b.getStatus())
                .paymentStatus(b.getPaymentStatus())
                .paymentMethod(b.getPaymentMethod())
                .totalPrice(b.getTotalPrice())
                .travelFee(b.getTravelFee())
                .notes(b.getNotes())
                .cancellationReason(b.getCancellationReason())
                .cancelledBy(b.getCancelledBy())
                .cancelledAt(b.getCancelledAt())
                .rejectionReason(b.getRejectionReason())
                .proposedDate(b.getProposedDate())
                .proposedStartTime(b.getProposedStartTime())
                .penaltyApplied(b.isPenaltyApplied())
                .commissionAmount(b.getCommissionAmount())
                .checkedInAt(b.getCheckedInAt())
                .createdAt(b.getCreatedAt())
                .reviewed(b.getReviews() != null && !b.getReviews().isEmpty())
                .build();
    }

    private ApiResponse.UserDto toUserDto(User u) {
        return ApiResponse.UserDto.builder().id(u.getId()).fullName(u.getFullName())
                .email(u.getEmail()).phone(u.getPhone())
                .role(u.getRole()).gender(u.getGender()).active(u.isActive()).build();
    }

    private ApiResponse.ProviderSummaryDto toProviderSummary(ProviderProfile p) {
        return ApiResponse.ProviderSummaryDto.builder().id(p.getId())
                .businessName(p.getBusinessName()).address(p.getAddress())
                .averageRating(p.getAverageRating())
                .verificationStatus(p.getVerificationStatus()).build();
    }

    private ApiResponse.ServiceDto toServiceDto(com.aiwa.entity.Service s) {
        return ApiResponse.ServiceDto.builder().id(s.getId()).name(s.getName())
                .price(s.getPrice()).durationMinutes(s.getDurationMinutes())
                .pricingType(s.getPricingType()).transportIncluded(s.isTransportIncluded()).build();
    }

    private ApiResponse.StaffMemberDto toStaffDto(StaffMember s) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
                .phone(s.getPhone())
                .active(s.isActive())
                .build();
    }

    private ApiResponse.SavedAddressDto toAddressDto(SavedAddress a) {
        return ApiResponse.SavedAddressDto.builder()
                .id(a.getId())
                .label(a.getLabel())
                .addressLine(a.getAddressLine())
                .latitude(a.getLatitude())
                .longitude(a.getLongitude())
                .defaultAddress(a.isDefaultAddress())
                .build();
    }
}
