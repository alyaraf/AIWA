package com.aiwa.service.impl;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.request.RescheduleRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ConflictException;
import com.aiwa.exception.ForbiddenException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.BookingService;
import com.aiwa.util.AiwaTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
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

    /** How far ahead a customer can book. */
    static final int MAX_DAYS_AHEAD = 90;
    /** Upper bound for a per-booking travel quote (EGP) — guards against typos like 15000. */
    static final BigDecimal MAX_TRAVEL_QUOTE = new BigDecimal("5000");

    /** Hours after completion in which the customer may report "not paid" (CR-03). */
    @org.springframework.beans.factory.annotation.Value("${aiwa.booking.payment-dispute-window-hours:48}")
    private long paymentDisputeWindowHours = 48;

    /** States in which both parties may see each other's phone number. */
    static final Set<BookingStatus> CONTACT_VISIBLE = EnumSet.of(
            BookingStatus.ACCEPTED, BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS);

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
     *                       duplicate. When absent, the same guard is applied
     *                       automatically, keyed on the booking's own content
     *                       (customer + provider + service + staff + slot) for a short
     *                       window, so an accidental double submit is still caught.
     */
    @Transactional
    public ApiResponse.BookingDto create(Long customerId, BookingRequest req, String idempotencyKey) {
        boolean explicitKey = idempotencyKey != null && !idempotencyKey.isBlank();
        if (explicitKey) {
            // DR-024: the key is stored with the booking, so a retry after the
            // 5-minute Redis window (or with Redis down) still finds the original,
            // and the same key with a different request is refused, not answered
            // with the earlier booking.
            String key = clipKey(idempotencyKey);
            Optional<Booking> earlier = bookingRepo.findByCustomerIdAndIdempotencyKey(customerId, key);
            if (earlier.isPresent()) {
                if (!sameRequest(earlier.get(), req)) throw new ConflictException("booking.error.idempotency_key_reused");
                return toDto(earlier.get());
            }
        }
        String dedupKey = explicitKey
                ? "idem:booking:" + customerId + ":" + idempotencyKey.trim()
                : "idem:booking:" + customerId + ":auto:" + autoDedupFingerprint(req);
        Duration ttl = explicitKey ? IDEMPOTENCY_KEY_TTL : AUTO_DEDUP_WINDOW;

        // The dedup guard is a convenience, not the primary correctness boundary
        // (the locked slot-conflict check below still applies) — if Redis is
        // unreachable, skip it rather than failing every booking attempt outright.
        boolean claimedHere;
        try {
            claimedHere = redis.setIfAbsent(dedupKey, "pending", ttl);
        } catch (RuntimeException e) {
            log.warn("Idempotency check unavailable (Redis down?) — creating without it: {}", e.getMessage());
            return doCreate(customerId, req, explicitKey ? clipKey(idempotencyKey) : null);
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
                Booking original = bookingRepo.findById(Long.valueOf(claimed))
                        .orElseThrow(() -> new BusinessException("booking.error.duplicate"));
                if (!original.getCustomer().getId().equals(customerId)) {
                    throw new BusinessException("booking.error.duplicate");
                }
                if (!sameRequest(original, req)) throw new ConflictException("booking.error.idempotency_key_reused");
                return toDto(original);
            } catch (NumberFormatException e) {
                throw new BusinessException("booking.error.duplicate");
            }
        }

        try {
            ApiResponse.BookingDto dto = doCreate(customerId, req, explicitKey ? clipKey(idempotencyKey) : null);
            // Only once the booking is committed (DR-024): written inside the
            // transaction, a rollback left the key pointing at a booking that
            // never existed.
            afterCommit(() -> redis.set(dedupKey, String.valueOf(dto.getId()), IDEMPOTENCY_KEY_TTL));
            return dto;
        } catch (RuntimeException e) {
            // The request was rejected outright (bad input, no slot, etc.) — release
            // the claim so a corrected retry isn't blocked by our own guard.
            try {
                redis.delete(dedupKey);
            } catch (RuntimeException ignored) {
                // the claim expires on its own
            }
            throw e;
        }
    }

    private static String clipKey(String key) {
        String k = key.trim();
        return k.length() > 100 ? k.substring(0, 100) : k;
    }

    /** Whether a stored booking was created from (what looks like) the same request. */
    private static boolean sameRequest(Booking b, BookingRequest req) {
        boolean same = Objects.equals(b.getProvider().getId(), req.getProviderId())
                && Objects.equals(b.getService().getId(), req.getServiceId())
                && Objects.equals(b.getStaffMember() != null ? b.getStaffMember().getId() : null, req.getStaffMemberId())
                && b.getBookingType() == req.getBookingType();
        if (same && req.getBookingType() != BookingType.BOOK_NOW) {
            same = Objects.equals(b.getBookingDate(), req.getBookingDate())
                    && Objects.equals(b.getStartTime(), req.getStartTime());
        }
        return same;
    }

    private static void afterCommit(Runnable action) {
        Runnable guarded = () -> {
            try {
                action.run();
            } catch (RuntimeException e) {
                log.warn("Post-commit step failed: {}", e.getMessage());
            }
        };
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override
                        public void afterCommit() {
                            guarded.run();
                        }
                    });
        } else {
            guarded.run();
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

    private ApiResponse.BookingDto doCreate(Long customerId, BookingRequest req, String idempotencyKey) {
        User customer = userRepo.findById(customerId)
                .orElseThrow(() -> new ResourceNotFoundException("User", customerId));
        // Row lock on the provider serializes concurrent bookings of the same
        // calendar, so the conflict check below cannot be passed twice for one slot.
        ProviderProfile provider = providerRepo.findByIdForUpdate(req.getProviderId())
                .orElseThrow(() -> new ResourceNotFoundException("Provider", req.getProviderId()));
        com.aiwa.entity.Service service = serviceRepo.findById(req.getServiceId())
                .orElseThrow(() -> new ResourceNotFoundException("Service", req.getServiceId()));

        if (!service.isActive())
            throw new BusinessException("service.inactive");
        if (!service.getProvider().getId().equals(provider.getId()))
            throw new BusinessException("service.wrong_provider");
        requireAcceptingBookings(provider);
        if (provider.getUser().getId().equals(customerId))
            throw new BusinessException("booking.error.own_listing");

        StaffMember staffMember = null;
        if (req.getStaffMemberId() != null) {
            staffMember = staffRepo.findByIdAndProviderId(req.getStaffMemberId(), provider.getId())
                    .orElseThrow(() -> new BusinessException("booking.error.staff_wrong_provider"));
            if (!staffMember.isActive()) throw new BusinessException("booking.error.staff_unavailable");
            if (!staffMember.performs(service)) throw new BusinessException("booking.error.staff_not_offering_service");
        }

        SavedAddress savedAddress = null;
        if (req.getSavedAddressId() != null) {
            savedAddress = savedAddressRepo.findById(req.getSavedAddressId())
                    .orElseThrow(() -> new ResourceNotFoundException("Saved address", req.getSavedAddressId()));
            if (!savedAddress.getUser().getId().equals(customerId)) {
                throw new BusinessException("booking.error.address_wrong_customer");
            }
        }

        // ── BOOK_NOW — today + next available slot ────────────────────────────
        LocalDate bookingDate;
        LocalTime startTime;

        if (req.getBookingType() == BookingType.BOOK_NOW) {
            bookingDate = AiwaTime.today();
            startTime   = findNextAvailableSlot(provider.getId(), staffMember, service, bookingDate);
        } else {
            if (req.getBookingDate() == null || req.getStartTime() == null)
                throw new BusinessException("booking.error.date_time_required");
            bookingDate = req.getBookingDate();
            startTime   = req.getStartTime();
        }
        // CR-04: the slot Book Now picked gets the same check as a scheduled one.
        requireBookableSlot(provider, staffMember, service, bookingDate, startTime);

        LocalTime endTime = startTime.plusMinutes(service.getDurationMinutes());
        requireFree(provider, staffMember, bookingDate, startTime, service.getDurationMinutes(), null);

        Integer eta = (req.getBookingType() == BookingType.BOOK_NOW)
                ? estimateArrivalMinutes(provider, savedAddress) : null;

        // Home-service travel fee: snapshot the provider's current fee onto the
        // booking so later profile edits don't retroactively rewrite this receipt.
        // Null / zero on the provider means "no travel charge" — treat as absent.
        boolean isHomeService = Boolean.TRUE.equals(req.getHomeService());
        BigDecimal travelFee = null;
        BigDecimal total = service.getPrice();
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
                .idempotencyKey(idempotencyKey)
                .paymentStatus(PaymentStatus.CASH_PENDING)
                .paymentMethod("CASH")
                .build();

        Booking saved = bookingRepo.save(booking);

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

    /**
     * A scheduled slot must be in the future, within the booking horizon, and
     * inside the provider's (or chosen staff member's) working hours for that day.
     * Before, any date/time was accepted — including the past and 3 a.m.
     */
    private void requireBookableSlot(ProviderProfile provider, StaffMember staff,
                                     com.aiwa.entity.Service service, LocalDate date, LocalTime start) {
        LocalDateTime startsAt = LocalDateTime.of(date, start);
        if (!startsAt.isAfter(AiwaTime.now())) {
            throw new BusinessException("booking.error.slot_in_past");
        }
        if (date.isAfter(AiwaTime.today().plusDays(MAX_DAYS_AHEAD))) {
            throw new BusinessException("booking.error.too_far_ahead");
        }
        Availability avail = resolveAvailability(provider.getId(), staff != null ? staff.getId() : null,
                date.getDayOfWeek());
        if (avail == null || !avail.isAvailable()) {
            throw new BusinessException("booking.error.provider_not_working");
        }
        LocalTime end = start.plusMinutes(service.getDurationMinutes());
        if (start.isBefore(avail.getStartTime()) || end.isAfter(avail.getEndTime()) || end.isBefore(start)) {
            throw new BusinessException("booking.error.outside_working_hours");
        }
    }

    private static int bufferOf(ProviderProfile provider) {
        return provider.getTravelBufferMinutes() != null ? provider.getTravelBufferMinutes() : 0;
    }

    /**
     * The provider can take a booking right now. DR-014: a suspended or deleted
     * owner account used to keep receiving bookings because only the listing's
     * own flags were checked.
     */
    static void requireAcceptingBookings(ProviderProfile provider) {
        if (provider.getVerificationStatus() != VerificationStatus.APPROVED
                || provider.getUser() == null || !provider.getUser().isActive())
            throw new BusinessException("booking.error.provider_unavailable");
        if (provider.isVacationMode() || provider.isOfflineMode() || provider.isSettlementPaused())
            throw new BusinessException("booking.error.provider_not_accepting");
    }

    /**
     * Bookings that block the calendar a booking would use (DR-023): a staff
     * member's own bookings plus the shop's unassigned ones; for an unassigned
     * booking, everything at the provider. The day before and after are included
     * so a buffer that crosses midnight is seen (R2-07).
     */
    private List<Booking> calendar(Long providerId, Long staffId, LocalDate date, Long excludeId) {
        return bookingRepo.findActiveForCalendar(providerId, date.minusDays(1), date.plusDays(1)).stream()
                .filter(b -> excludeId == null || !excludeId.equals(b.getId()))
                .filter(b -> staffId == null || b.getStaffMember() == null || staffId.equals(b.getStaffMember().getId()))
                .toList();
    }

    static LocalDateTime startOf(Booking b) {
        return LocalDateTime.of(b.getBookingDate(), b.getStartTime());
    }

    static LocalDateTime endOf(Booking b) {
        LocalDateTime start = startOf(b);
        LocalDateTime end = LocalDateTime.of(b.getBookingDate(), b.getEndTime());
        return end.isAfter(start) ? end : end.plusDays(1);
    }

    /**
     * R2-07: the travel buffer keeps a gap on both sides of every booking, and
     * the comparison uses full date-times. Before, the buffer was only added
     * after the new booking (so 10:00 then 11:00 both fitted with a 120-minute
     * buffer) and a buffered end past midnight wrapped to the small hours, which
     * let two 21:30 bookings through.
     */
    static boolean overlaps(List<Booking> busy, LocalDateTime start, LocalDateTime end, int bufferMinutes) {
        for (Booking b : busy) {
            if (start.isBefore(endOf(b).plusMinutes(bufferMinutes))
                    && startOf(b).isBefore(end.plusMinutes(bufferMinutes))) {
                return true;
            }
        }
        return false;
    }

    private void requireFree(ProviderProfile provider, StaffMember staff, LocalDate date, LocalTime start,
                             int durationMinutes, Long excludeId) {
        LocalDateTime s = LocalDateTime.of(date, start);
        List<Booking> busy = calendar(provider.getId(), staff != null ? staff.getId() : null, date, excludeId);
        if (overlaps(busy, s, s.plusMinutes(durationMinutes), bufferOf(provider))) {
            throw new ConflictException("booking.error.conflict");
        }
    }

    // ── READ ───────────────────────────────────────────────────────────────────

    @Override
    @Transactional(readOnly = true)
    public ApiResponse.BookingDto getById(Long bookingId, Long requesterId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean isOwner = booking.getCustomer().getId().equals(requesterId)
                || booking.getProvider().getUser().getId().equals(requesterId);
        if (!isOwner) throw new ForbiddenException("error.access_denied");
        ApiResponse.BookingDto dto = toDto(booking);
        // The provider's booking detail shows "N bookings" for the customer.
        if (dto.getCustomer() != null) {
            dto.getCustomer().setBookingCount(bookingRepo.countByCustomerId(booking.getCustomer().getId()));
        }
        return dto;
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getMyBookings(Long customerId, Pageable pageable) {
        return getMyBookings(customerId, null, pageable);
    }

    /** @param statuses optional filter (BE-9) — null/empty means every status. */
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getMyBookings(Long customerId, Collection<BookingStatus> statuses,
                                                      Pageable pageable) {
        Page<Booking> page = statuses == null || statuses.isEmpty()
                ? bookingRepo.findByCustomerIdOrderByCreatedAtDesc(customerId, pageable)
                : bookingRepo.findByCustomerIdAndStatusInOrderByCreatedAtDesc(customerId, statuses, pageable);
        return page.map(this::toDto);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getProviderBookings(Long userId, Pageable pageable) {
        return getProviderBookings(userId, null, false, pageable);
    }

    /**
     * @param statuses optional filter (BE-9) — null/empty means every status
     * @param newestFirst "Past" lists want the most recent visit first; upcoming lists the soonest
     */
    @Transactional(readOnly = true)
    public Page<ApiResponse.BookingDto> getProviderBookings(Long userId, Collection<BookingStatus> statuses,
                                                            boolean newestFirst, Pageable pageable) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        Long pid = profile.getId();
        boolean filtered = statuses != null && !statuses.isEmpty();
        Page<Booking> page;
        if (newestFirst) {
            page = filtered
                    ? bookingRepo.findByProviderIdAndStatusInOrderByBookingDateDescStartTimeDesc(pid, statuses, pageable)
                    : bookingRepo.findByProviderIdOrderByBookingDateDescStartTimeDesc(pid, pageable);
        } else {
            page = filtered
                    ? bookingRepo.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc(pid, statuses, pageable)
                    : bookingRepo.findByProviderIdOrderByBookingDateAscStartTimeAsc(pid, pageable);
        }
        return page.map(this::toDto);
    }

    /**
     * BE-16 (MVP call button): the other party's phone, only while the booking
     * is live (accepted → in progress). Before and after that window there is
     * no reason for either side to hold the other's number.
     */
    @Transactional(readOnly = true)
    public ApiResponse.BookingContactDto getContact(Long bookingId, Long requesterId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean isCustomer = booking.getCustomer().getId().equals(requesterId);
        boolean isProvider = booking.getProvider().getUser().getId().equals(requesterId);
        if (!isCustomer && !isProvider) throw new ForbiddenException("error.access_denied");
        if (!CONTACT_VISIBLE.contains(booking.getStatus())) {
            throw new BusinessException("booking.error.contact_not_available");
        }
        User other = isCustomer ? booking.getProvider().getUser() : booking.getCustomer();
        String phone = isCustomer && booking.getStaffMember() != null && booking.getStaffMember().getPhone() != null
                ? booking.getStaffMember().getPhone()   // a shop booking: call the assigned staff member
                : other.getPhone();
        if (phone == null || phone.isBlank()) {
            throw new BusinessException("booking.error.contact_no_phone");
        }
        return ApiResponse.BookingContactDto.builder()
                .bookingId(bookingId)
                .name(isCustomer ? booking.getProvider().getBusinessName() : other.getFullName())
                .phone(phone)
                .role(isCustomer ? "PROVIDER" : "CUSTOMER")
                .build();
    }

    // ── STATUS UPDATE ──────────────────────────────────────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingDto updateStatus(Long userId, Long bookingId, BookingStatus newStatus) {
        return updateStatus(userId, bookingId, newStatus, null);
    }

    /** @param reason cancellation reason (stored on the booking; ignored for other transitions) */
    @Transactional
    public ApiResponse.BookingDto updateStatus(Long userId, Long bookingId, BookingStatus newStatus, String reason) {
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
        if (!isProvider && !isCustomer) throw new ForbiddenException("error.not_authorized");

        if (!booking.getStatus().canTransitionTo(newStatus)) {
            throw new BusinessException("Cannot change status from "
                    + booking.getStatus() + " to " + newStatus);
        }

        if (newStatus != BookingStatus.CANCELLED && !isProvider) {
            throw new BusinessException("booking.error.only_provider_update_status");
        }

        BookingStatus previous = booking.getStatus();
        requireStepAllowed(booking, newStatus);
        if (newStatus == BookingStatus.CANCELLED) {
            if (isCustomer) enforceCustomerCancellationCutoff(booking);
            booking.setCancelledBy(isCustomer ? "CUSTOMER" : "PROVIDER");
            booking.setCancelledAt(LocalDateTime.now());
            booking.setCancellationReason(trimReason(reason));
            // A provider walking away from a commitment they accepted costs a strike
            // and a penalty; declining a request they never accepted does not.
            if (isProvider && previous != BookingStatus.PENDING) {
                ProviderProfile provider = booking.getProvider();
                provider.setCancellationStrikes(provider.getCancellationStrikes() + 1);
                providerRepo.save(provider);
                booking.setPenaltyApplied(true);
            }
        }

        if (newStatus == BookingStatus.NO_SHOW) {
            // Only once the appointment has started: before that the customer
            // can't be absent yet, and a no-show counts against them.
            if (booking.getBookingDate() != null && booking.getStartTime() != null
                    && AiwaTime.now().isBefore(LocalDateTime.of(booking.getBookingDate(), booking.getStartTime()))) {
                throw new BusinessException("booking.error.no_show_too_early");
            }
            booking.setPenaltyApplied(true);
        }

        booking.setStatus(newStatus);
        bookingRepo.save(booking);

        sendStatusNotification(booking, newStatus, isCustomer);
        return toDto(booking);
    }

    /** How early before the appointment a provider may set off, start, or finish (R2-17). */
    static final int ON_THE_WAY_LEAD_MINUTES = 180;
    static final int START_LEAD_MINUTES = 60;

    /**
     * Rules the plain transition table can't express:
     * <ul>
     *   <li>DR-021: no setting off or starting while the customer hasn't answered a travel quote;</li>
     *   <li>home visits go accepted → on the way → arrived → started, and only an arrived
     *       provider can report a no-show; venue bookings never go "on the way";</li>
     *   <li>a venue customer who checked in can't be marked a no-show;</li>
     *   <li>R2-17: no setting off more than 3 h, or starting / completing more than 1 h,
     *       before the appointment.</li>
     * </ul>
     */
    private static void requireStepAllowed(Booking booking, BookingStatus next) {
        BookingStatus current = booking.getStatus();
        if ((next == BookingStatus.ON_THE_WAY || next == BookingStatus.IN_PROGRESS)
                && booking.getTravelFeeQuoteStatus() == TravelFeeQuoteStatus.PENDING) {
            throw new BusinessException("booking.error.quote_pending");
        }
        if (booking.isHomeService()) {
            if (current == BookingStatus.ACCEPTED && (next == BookingStatus.IN_PROGRESS || next == BookingStatus.NO_SHOW)) {
                throw new BusinessException("booking.error.home_visit_steps");
            }
        } else {
            if (next == BookingStatus.ON_THE_WAY) throw new BusinessException("booking.error.venue_no_travel");
            if (next == BookingStatus.NO_SHOW && booking.getCheckedInAt() != null) {
                throw new BusinessException("booking.error.customer_checked_in");
            }
        }
        if (booking.getBookingDate() == null || booking.getStartTime() == null) return;
        LocalDateTime startsAt = LocalDateTime.of(booking.getBookingDate(), booking.getStartTime());
        int lead = next == BookingStatus.ON_THE_WAY ? ON_THE_WAY_LEAD_MINUTES
                : (next == BookingStatus.IN_PROGRESS || next == BookingStatus.COMPLETED) ? START_LEAD_MINUTES : -1;
        if (lead >= 0 && AiwaTime.now().isBefore(startsAt.minusMinutes(lead))) {
            throw new BusinessException("booking.error.too_early_for_step");
        }
    }

    private static String trimReason(String reason) {
        if (reason == null || reason.isBlank()) return null;
        String r = reason.trim();
        return r.length() > 255 ? r.substring(0, 255) : r;
    }

    // ── COMPLETE + payment outcome (cash vs disputed) ──────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingDto complete(Long userId, Long bookingId, boolean cashCollected) {
        return complete(userId, bookingId, cashCollected, null);
    }

    /**
     * Provider marks a booking COMPLETED. When cash was collected the booking is
     * CASH_CONFIRMED and platform commission is recorded; otherwise it is flagged
     * DISPUTED, admins are notified, and no commission is charged. The optional
     * note explains a cash-not-collected completion to the admin reviewing it.
     */
    @Transactional
    public ApiResponse.BookingDto complete(Long userId, Long bookingId, boolean cashCollected, String note) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(userId))
            throw new BusinessException("booking.error.only_provider_complete");
        if (!booking.getStatus().canTransitionTo(BookingStatus.COMPLETED))
            throw new BusinessException("Cannot complete booking in status: " + booking.getStatus());
        requireStepAllowed(booking, BookingStatus.COMPLETED);

        booking.setStatus(BookingStatus.COMPLETED);
        booking.setCompletedAt(AiwaTime.now());
        if (note != null && !note.isBlank()) {
            String n = note.trim();
            booking.setCompletionNote(n.length() > 500 ? n.substring(0, 500) : n);
        }

        if (cashCollected) {
            booking.setPaymentStatus(PaymentStatus.CASH_CONFIRMED);
            bookingRepo.save(booking);
            recordCommissionIfNeeded(booking);
        } else {
            booking.setPaymentStatus(PaymentStatus.DISPUTED);
            bookingRepo.save(booking);
            notifyAdminsOfDispute(booking);
        }

        sendStatusNotification(booking, BookingStatus.COMPLETED, false);
        return toDto(booking);
    }

    /** Admin override: force-cancel any non-terminal booking. */
    @Override
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
        booking.setCancellationReason(reason != null && !reason.isBlank() ? trimReason(reason) : "Cancelled by admin");
        booking.setCancelledAt(LocalDateTime.now());
        bookingRepo.save(booking);

        notifyCustomer(booking, NotificationType.BOOKING_CANCELLED,
                "Booking cancelled by admin", "تم إلغاء الحجز من قبل الإدارة",
                "Your booking for " + booking.getService().getName() + " was cancelled by AIWA support.",
                "تم إلغاء حجزك لـ " + booking.getService().getName() + " من قبل دعم AIWA.");
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
    @Override
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
    @Override
    @Transactional
    public ApiResponse.BookingDto adminResolveDispute(Long bookingId, String outcome) {
        return adminResolveDispute(bookingId, outcome, null);
    }

    @Transactional
    public ApiResponse.BookingDto adminResolveDispute(Long bookingId, String outcome, String reason) {
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
                recordResolution(booking, choice);
                bookingRepo.save(booking);
                recordCommissionIfNeeded(booking);
                summaryEn = "paid";
            }
            case "UNPAID" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                recordResolution(booking, choice);
                bookingRepo.save(booking);
                voidCommission(booking);
                summaryEn = "written off (unpaid)";
            }
            case "NO_SHOW" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                booking.setStatus(BookingStatus.NO_SHOW);
                booking.setPenaltyApplied(true);
                recordResolution(booking, choice);
                bookingRepo.save(booking);
                voidCommission(booking);
                summaryEn = "no-show recorded";
            }
            case "CANCEL" -> {
                booking.setPaymentStatus(PaymentStatus.UNPAID);
                booking.setStatus(BookingStatus.CANCELLED);
                booking.setCancelledBy("ADMIN");
                booking.setCancellationReason(reason != null && !reason.isBlank()
                        ? trimReason(reason) : "Voided during dispute resolution");
                booking.setCancelledAt(LocalDateTime.now());
                recordResolution(booking, choice);
                bookingRepo.save(booking);
                voidCommission(booking);
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
        notifyCustomer(booking, NotificationType.PAYMENT_DISPUTED,
                "Payment dispute resolved", "تم حل نزاع الدفع",
                "AIWA support resolved the payment question on your " + booking.getService().getName()
                        + " booking (" + summaryEn + ").",
                "قام دعم AIWA بحل مسألة الدفع لحجزك لـ " + booking.getService().getName() + ".");
        return toDto(booking);
    }

    /** CR-03: the admin's outcome is kept on the booking (outcome, when, who) and is final. */
    private static void recordResolution(Booking booking, String outcome) {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        booking.setPaymentResolution(outcome);
        booking.setPaymentResolvedAt(AiwaTime.now());
        booking.setPaymentResolvedBy(auth != null && auth.getName() != null ? auth.getName() : "system");
    }

    /** Customer checks in at an on-site/venue booking so the provider can begin. */
    @Override
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
    @Override
    @Transactional
    public ApiResponse.BookingDto confirmPayment(Long customerId, Long bookingId, boolean paid) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_confirm_payment");
        if (booking.getStatus() != BookingStatus.COMPLETED)
            throw new BusinessException("booking.error.payment_confirm_requires_completed");
        // R2-08: the customer answers only while the payment is open. Once it is
        // disputed or an admin has resolved it, "paid" used to re-create a
        // commission the admin had written off, and "not paid" reopened a
        // resolved dispute with its commission kept.
        PaymentStatus payment = booking.getPaymentStatus();
        // CR-03: an admin's outcome is final. A PAID outcome leaves CASH_CONFIRMED,
        // which used to accept "not paid" again: the dispute reopened, the
        // commission was voided and every admin was notified, without limit.
        if (booking.getPaymentResolution() != null)
            throw new BusinessException("booking.error.payment_already_resolved");
        if (payment == PaymentStatus.CASH_CONFIRMED && paid) return toDto(booking); // already confirmed
        if (payment != PaymentStatus.CASH_PENDING && payment != PaymentStatus.CASH_CONFIRMED)
            throw new BusinessException("booking.error.payment_already_resolved");
        if (!paid) {
            // "Not paid" counts once per booking, and only for a while after completion.
            if (booking.getCustomerDisputedAt() != null)
                throw new BusinessException("booking.error.payment_dispute_already_reported");
            // Bookings completed before completedAt existed: the scheduled end.
            LocalDateTime completed = booking.getCompletedAt() != null ? booking.getCompletedAt() : endOf(booking);
            if (!AiwaTime.now().isBefore(completed.plusHours(paymentDisputeWindowHours)))
                throw new BusinessException("booking.error.payment_dispute_window_closed");
        }

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
            booking.setCustomerDisputedAt(AiwaTime.now());
            bookingRepo.save(booking);
            // No commission while the dispute is open; the admin's outcome decides.
            voidCommission(booking);
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
                        "Booking #" + booking.getId() + " was completed but cash was not confirmed."
                                + (booking.getCompletionNote() != null
                                    ? " Provider note: " + booking.getCompletionNote() : ""),
                        "تم إكمال الحجز رقم " + booking.getId() + " لكن لم يتم تأكيد الدفع النقدي.",
                        booking.getId(), booking.getProvider().getId()
                ));
    }

    // ── EXPIRY (system) ────────────────────────────────────────────────────────

    /**
     * Expire PENDING requests the provider never answered within the response
     * window. When the provider proposed another time, the customer's clock runs
     * from the proposal — before, a proposal made late in the window left the
     * customer only minutes to answer before the whole request expired.
     */
    @Transactional
    public int expireStalePendingBookings() {
        LocalDateTime now = LocalDateTime.now();
        List<Booking> stale = bookingRepo.findByStatus(BookingStatus.PENDING).stream()
                .filter(b -> b.getCreatedAt() != null)
                .filter(b -> waitingSince(b).isBefore(now.minusMinutes(platformSettings.getResponseWindowMinutes(b.getProvider()))))
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

    /**
     * When the current wait for an answer began: creation, the provider's latest
     * proposal, or the customer's latest reschedule (R2-01: a reschedule of a
     * booking accepted days ago used to be expired by the next sweep).
     */
    static LocalDateTime waitingSince(Booking b) {
        LocalDateTime ref = b.getCreatedAt();
        if (b.getProposedAt() != null && b.getProposedAt().isAfter(ref)) ref = b.getProposedAt();
        if (b.getAwaitingSince() != null && b.getAwaitingSince().isAfter(ref)) ref = b.getAwaitingSince();
        return ref;
    }

    // ── PROVIDER PROPOSES ALTERNATIVE TIME (customer accept/decline) ───────────

    @Override
    @Transactional
    public ApiResponse.BookingDto proposeReschedule(Long providerUserId, Long bookingId, RescheduleRequest req) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(providerUserId))
            throw new BusinessException("booking.error.only_provider_propose");
        if (booking.getStatus() != BookingStatus.PENDING)
            throw new BusinessException("booking.error.propose_requires_pending");

        ProviderProfile provider = providerRepo.findByIdForUpdate(booking.getProvider().getId())
                .orElseThrow(() -> new ResourceNotFoundException("Provider", booking.getProvider().getId()));
        requireBookableSlot(provider, booking.getStaffMember(), booking.getService(),
                req.getBookingDate(), req.getStartTime());
        requireFreeSlot(booking, req.getBookingDate(), req.getStartTime());

        booking.setProposedDate(req.getBookingDate());
        booking.setProposedStartTime(req.getStartTime());
        booking.setProposedAt(LocalDateTime.now());
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

    @Override
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
            if (!LocalDateTime.of(d, s).isAfter(AiwaTime.now()))
                throw new BusinessException("booking.error.proposal_lapsed");
            // DR-022: the provider's situation may have changed since proposing
            // (hours, vacation, offline, suspension, the staff member). Check it
            // all again under the provider lock, like a new booking.
            ProviderProfile provider = providerRepo.findByIdForUpdate(booking.getProvider().getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Provider", booking.getProvider().getId()));
            requireAcceptingBookings(provider);
            if (booking.getStaffMember() != null && !booking.getStaffMember().isActive())
                throw new BusinessException("booking.error.staff_unavailable");
            requireBookableSlot(provider, booking.getStaffMember(), booking.getService(), d, s);
            requireFreeSlot(booking, d, s);

            booking.setBookingDate(d);
            booking.setStartTime(s);
            booking.setEndTime(e);
            booking.setStatus(BookingStatus.ACCEPTED);
            booking.setProposedDate(null);
            booking.setProposedStartTime(null);
            booking.setProposedAt(null);
            bookingRepo.save(booking);

            sendStatusNotification(booking, BookingStatus.ACCEPTED, false);
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
            booking.setProposedAt(null);
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

    /** The slot (plus travel buffer) must be free on the booking's own calendar, ignoring the booking itself. */
    private void requireFreeSlot(Booking booking, LocalDate date, LocalTime start) {
        requireFree(booking.getProvider(), booking.getStaffMember(), date, start,
                booking.getService().getDurationMinutes(), booking.getId());
    }

    // ── PER-BOOKING TRAVEL-FEE QUOTE (BE-17) ───────────────────────────────────

    /**
     * Provider quotes a travel fee for one home-service booking (e.g. a far-away
     * address). The customer must accept before it applies; until then the
     * booking keeps its original total.
     */
    @Transactional
    public ApiResponse.BookingDto quoteTravelFee(Long providerUserId, Long bookingId, BigDecimal amount) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        if (!booking.getProvider().getUser().getId().equals(providerUserId))
            throw new ForbiddenException("error.not_authorized");
        if (!booking.isHomeService())
            throw new BusinessException("booking.error.quote_home_service_only");
        if (booking.getStatus() != BookingStatus.PENDING && booking.getStatus() != BookingStatus.ACCEPTED)
            throw new BusinessException("booking.error.quote_not_allowed_now");
        if (amount == null || amount.signum() < 0 || amount.compareTo(MAX_TRAVEL_QUOTE) > 0)
            throw new BusinessException("booking.error.quote_invalid_amount");

        booking.setTravelFeeQuote(amount.setScale(2, RoundingMode.HALF_UP));
        booking.setTravelFeeQuoteStatus(TravelFeeQuoteStatus.PENDING);
        bookingRepo.save(booking);

        notifyCustomer(booking, NotificationType.TRAVEL_FEE_QUOTED,
                "Travel fee quoted", "تم تحديد رسوم الانتقال",
                booking.getProvider().getBusinessName() + " quoted EGP " + booking.getTravelFeeQuote()
                        + " travel for your " + booking.getService().getName() + " booking. Accept or decline.",
                booking.getProvider().getBusinessName() + " حدد رسوم انتقال " + booking.getTravelFeeQuote()
                        + " جنيه لحجزك. اقبل أو ارفض.");
        return toDto(booking);
    }

    /**
     * Customer answers a travel quote. Accepting replaces the travel portion of
     * the total with the quote; declining cancels the booking without a
     * cancellation penalty to either side (the price changed, nobody defaulted).
     */
    @Transactional
    public ApiResponse.BookingDto respondToTravelFeeQuote(Long customerId, Long bookingId, boolean accept) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        if (!booking.getCustomer().getId().equals(customerId))
            throw new ForbiddenException("error.not_authorized");
        if (booking.getTravelFeeQuoteStatus() != TravelFeeQuoteStatus.PENDING)
            throw new BusinessException("booking.error.no_pending_quote");
        if (booking.getStatus() != BookingStatus.PENDING && booking.getStatus() != BookingStatus.ACCEPTED)
            throw new BusinessException("booking.error.quote_not_allowed_now");

        if (accept) {
            BigDecimal servicePortion = booking.getTotalPrice()
                    .subtract(booking.getTravelFee() != null ? booking.getTravelFee() : BigDecimal.ZERO);
            BigDecimal quote = booking.getTravelFeeQuote();
            booking.setTravelFee(quote.signum() > 0 ? quote : null);
            booking.setTotalPrice(servicePortion.add(quote));
            booking.setTravelFeeQuoteStatus(TravelFeeQuoteStatus.ACCEPTED);
        } else {
            booking.setTravelFeeQuoteStatus(TravelFeeQuoteStatus.DECLINED);
            booking.setStatus(BookingStatus.CANCELLED);
            booking.setCancelledBy("CUSTOMER");
            booking.setCancelledAt(LocalDateTime.now());
            booking.setCancellationReason("Travel fee quote declined");
        }
        bookingRepo.save(booking);

        notificationService.send(booking.getProvider().getUser().getId(), NotificationType.TRAVEL_FEE_RESPONSE,
                accept ? "Travel fee accepted" : "Travel fee declined",
                accept ? "تم قبول رسوم الانتقال" : "تم رفض رسوم الانتقال",
                booking.getCustomer().getFullName() + (accept
                        ? " accepted your travel quote." : " declined your travel quote; the booking was cancelled."),
                booking.getCustomer().getFullName() + (accept
                        ? " قبل رسوم الانتقال." : " رفض رسوم الانتقال وتم إلغاء الحجز."),
                booking.getId(), booking.getProvider().getId());
        return toDto(booking);
    }

    // ── REJECT with reason + return alternatives ───────────────────────────────

    @Override
    @Transactional
    public ApiResponse.BookingWithAlternativesDto rejectWithAlternatives(
            Long userId, Long bookingId, String reason) {

        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getProvider().getUser().getId().equals(userId))
            throw new ForbiddenException("error.not_authorized");
        if (!booking.getStatus().canTransitionTo(BookingStatus.REJECTED))
            throw new BusinessException("Cannot reject booking in status: " + booking.getStatus());
        String why = trimReason(reason);
        if (why == null) throw new BusinessException("booking.error.reason_required");

        booking.setStatus(BookingStatus.REJECTED);
        booking.setRejectionReason(why);
        booking.setCancelledAt(LocalDateTime.now());
        booking.setCancelledBy("PROVIDER");
        bookingRepo.save(booking);

        notificationService.send(
                booking.getCustomer().getId(),
                NotificationType.BOOKING_REJECTED,
                "Booking rejected",
                "تم رفض الحجز",
                "Your booking was rejected. Reason: " + why,
                "تم رفض حجزك. السبب: " + why,
                booking.getId(), booking.getProvider().getId()
        );

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
        if (!service.getProvider().getId().equals(providerId))
            throw new BusinessException("service.wrong_provider");

        DayOfWeek dow = date.getDayOfWeek();
        Availability avail = resolveAvailability(providerId, staffMemberId, dow);

        if (avail == null || !avail.isAvailable()) return Collections.emptyList();

        // The calendar the booking would use: the staff member's plus the shop's
        // unassigned bookings, with the neighbouring days for buffers (DR-023, R2-07).
        List<Booking> existing = calendar(providerId, staffMemberId, date, null);
        List<ApiResponse.TimeSlotDto> slots = new ArrayList<>();
        int duration = service.getDurationMinutes();
        int step = avail.getSlotDurationMinutes() != null && avail.getSlotDurationMinutes() > 0
                ? avail.getSlotDurationMinutes() : 30;
        int buffer = bufferOf(service.getProvider());
        LocalDateTime now = AiwaTime.now();

        // CR-04: minutes of the day, so a slot whose end passes midnight is not
        // mistaken for one that ends before closing time.
        int closing = minuteOfDay(avail.getEndTime());
        for (int m = minuteOfDay(avail.getStartTime()); m + duration <= closing; m += step) {
            final LocalTime slotStart = LocalTime.of(m / 60, m % 60);
            final LocalTime slotEnd   = slotStart.plusMinutes(duration);
            LocalDateTime s = LocalDateTime.of(date, slotStart);
            boolean taken = overlaps(existing, s, s.plusMinutes(duration), buffer);
            // A slot that has already started can't be booked either.
            boolean past = !LocalDateTime.of(date, slotStart).isAfter(now);

            slots.add(ApiResponse.TimeSlotDto.builder()
                    .startTime(slotStart).endTime(slotEnd).booked(taken || past).build());
        }
        return slots;
    }

    private static int minuteOfDay(LocalTime t) {
        return t.getHour() * 60 + t.getMinute();
    }

    // ── HELPERS ────────────────────────────────────────────────────────────────

    /**
     * Resolve the applicable availability for a day: a staff member's own row when
     * present, otherwise the provider-level row (fallback for shops without per-staff
     * hours, and the normal case for individuals).
     */
    private Availability resolveAvailability(Long providerId, Long staffMemberId, DayOfWeek dow) {
        if (staffMemberId != null) {
            Availability staffAvail = availabilityRepo
                    .findByProviderIdAndStaffMemberIdAndDayOfWeek(providerId, staffMemberId, dow)
                    .orElse(null);
            if (staffAvail != null) return staffAvail;
        }
        return availabilityRepo.findByProviderIdAndStaffMemberIsNullAndDayOfWeek(providerId, dow)
                .orElseGet(() -> availabilityRepo.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc(providerId, dow).orElse(null));
    }

    /** BOOK_NOW: the next free slot starting from now (Cairo time). */
    private LocalTime findNextAvailableSlot(Long providerId,
                                             StaffMember staff,
                                             com.aiwa.entity.Service service,
                                             LocalDate date) {
        DayOfWeek dow = date.getDayOfWeek();
        Long staffId = staff != null ? staff.getId() : null;
        Availability avail = resolveAvailability(providerId, staffId, dow);

        if (avail == null || !avail.isAvailable())
            throw new BusinessException("booking.error.provider_unavailable_today");

        List<Booking> existing = calendar(providerId, staffId, date, null);
        // CR-04: all in minutes of the day. Comparing clock times, a cursor plus
        // duration that passed midnight wrapped to a small time that was never
        // "after closing", so 23:10 against 09:00–17:00 booked 23:30.
        int now = minuteOfDay(AiwaTime.timeNow());
        int opening = minuteOfDay(avail.getStartTime());
        int closing = minuteOfDay(avail.getEndTime());
        int slot = avail.getSlotDurationMinutes() != null && avail.getSlotDurationMinutes() > 0
                ? avail.getSlotDurationMinutes() : 30;
        // from now + 5 min (or opening time), rounded up to the next slot boundary
        int first = now >= opening ? now + 5 : opening;
        first = ((first + slot - 1) / slot) * slot;

        int duration = service.getDurationMinutes();
        int buffer = service.getProvider() != null ? bufferOf(service.getProvider()) : 0;
        for (int m = first; m + duration <= closing; m += slot) {
            final LocalTime s = LocalTime.of(m / 60, m % 60);
            LocalDateTime startsAt = LocalDateTime.of(date, s);
            if (!overlaps(existing, startsAt, startsAt.plusMinutes(duration), buffer)) return s;
        }
        throw new BusinessException("booking.error.no_book_now_slots");
    }

    /**
     * BOOK_NOW arrival estimate. Straight-line distance at an urban average of
     * ~20 km/h plus 10 minutes to get going, clamped to 15–90 minutes. Without a
     * customer location, falls back to a fixed 30 minutes. (Before this was a
     * random number between 20 and 40.)
     */
    static Integer estimateArrivalMinutes(ProviderProfile provider, SavedAddress address) {
        if (address == null || address.getLatitude() == null || address.getLongitude() == null
                || provider.getLatitude() == null || provider.getLongitude() == null) {
            return 30;
        }
        double km = GeoUtils.distanceKm(provider.getLatitude(), provider.getLongitude(),
                address.getLatitude(), address.getLongitude());
        long minutes = Math.round(10 + km / 20.0 * 60);
        return (int) Math.max(15, Math.min(90, minutes));
    }

    /**
     * R2-08: the ledger follows the payment outcome. An outstanding entry for a
     * booking that turned out unpaid, voided or a no-show is voided; one that
     * was already settled is left alone (the money moved) and logged for finance.
     */
    private void voidCommission(Booking booking) {
        commissionLedgerRepo.findByBookingId(booking.getId()).ifPresent(entry -> {
            if (entry.getStatus() == LedgerEntryStatus.DUE || entry.getStatus() == LedgerEntryStatus.OVERDUE) {
                entry.setStatus(LedgerEntryStatus.VOID);
                commissionLedgerRepo.save(entry);
                booking.setCommissionAmount(null);
                bookingRepo.save(booking);
            } else if (entry.getStatus() == LedgerEntryStatus.SETTLED) {
                log.warn("Booking #{} lost its payment after its commission was settled (ledger #{}): refund it to the provider",
                        booking.getId(), entry.getId());
            }
        });
    }

    private void recordCommissionIfNeeded(Booking booking) {
        Optional<CommissionLedgerEntry> existing = commissionLedgerRepo.findByBookingId(booking.getId());
        if (existing.isPresent()) {
            CommissionLedgerEntry entry = existing.get();
            if (entry.getStatus() == LedgerEntryStatus.VOID) {
                // A dispute resolved as paid after all: charge the commission again.
                entry.setStatus(LedgerEntryStatus.DUE);
                commissionLedgerRepo.save(entry);
                booking.setCommissionAmount(entry.getCommissionAmount());
                bookingRepo.save(booking);
            }
            return;
        }
        if (commissionLedgerRepo.existsByBookingId(booking.getId())) return;
        // Rate is the admin-editable platform setting at completion time; snapshotted
        // onto the ledger entry so historical entries keep the rate they were charged.
        BigDecimal pct = platformSettings.getCommissionPercentFor(booking.getProvider());
        // Commission is charged on the *service* portion only. Any home-service
        // travel fee is pass-through — the provider is paying Uber out of it, the
        // platform doesn't skim it. Ledger's bookingAmount still records the true
        // total the customer paid.
        BigDecimal commissionBase = booking.getTotalPrice();
        if (booking.getTravelFee() != null) {
            commissionBase = commissionBase.subtract(booking.getTravelFee());
        }
        BigDecimal commissionAmount = commissionBase
                .multiply(pct)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
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
        // A request the provider hasn't accepted yet can always be withdrawn.
        if (booking.getStatus() == BookingStatus.PENDING) return;
        LocalDateTime appointment = LocalDateTime.of(booking.getBookingDate(), booking.getStartTime());
        int cutoffHours = platformSettings.getCancellationCutoffHours(booking.getProvider());
        if (LocalDateTime.now().isAfter(appointment.minusHours(cutoffHours))) {
            throw new BusinessException(
                "Cancellation deadline passed. Must cancel at least "
                + cutoffHours + " hours before the appointment.");
        }
    }

    /** Alternative approved providers for the same service category, near the rejecting one. */
    private List<ApiResponse.ProviderSummaryDto> findAlternativeProviders(
            ProviderProfile rejected, com.aiwa.entity.Service service) {
        if (rejected.getLatitude() == null || rejected.getLongitude() == null) return List.of();
        return providerRepo.findNearby(rejected.getLatitude(), rejected.getLongitude(), 15.0)
                .stream()
                .filter(p -> !p.getId().equals(rejected.getId()))
                .filter(p -> p.getVerificationStatus() == VerificationStatus.APPROVED)
                .filter(p -> !p.isVacationMode() && !p.isOfflineMode() && !p.isSettlementPaused())
                .filter(p -> p.getPrimaryCategory() == service.getCategory()
                          || p.getServices().stream().anyMatch(
                                s -> s.isActive() && s.getCategory() == service.getCategory()))
                .limit(3)
                .map(p -> ApiResponse.ProviderSummaryDto.builder()
                        .id(p.getId())
                        .businessName(p.getBusinessName())
                        .ownerName(p.getUser().getFullName())
                        .address(p.getAddress())
                        .latitude(p.getLatitude())
                        .longitude(p.getLongitude())
                        .averageRating(p.getAverageRating())
                        .totalReviews(p.getTotalReviews())
                        .primaryCategory(p.getPrimaryCategory())
                        .verificationStatus(p.getVerificationStatus())
                        .build())
                .collect(Collectors.toList());
    }

    // ── RESCHEDULE ─────────────────────────────────────────────────────────────

    /**
     * Customer moves a PENDING/ACCEPTED booking. The new slot must be bookable
     * (future, within working hours) and free on the same calendar the booking
     * uses — ignoring the booking itself, so shifting by 30 minutes within its own
     * slot is no longer reported as a conflict.
     */
    @Override
    @Transactional
    public ApiResponse.BookingDto reschedule(Long customerId, Long bookingId, RescheduleRequest req) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));

        if (!booking.getCustomer().getId().equals(customerId))
            throw new BusinessException("booking.error.only_customer_reschedule");

        if (booking.getStatus() != BookingStatus.PENDING && booking.getStatus() != BookingStatus.ACCEPTED)
            throw new BusinessException("booking.error.reschedule_requires_pending_or_accepted");
        if (booking.getStatus() == BookingStatus.ACCEPTED) {
            // Moving an accepted appointment late is a late cancellation in disguise.
            enforceCustomerCancellationCutoff(booking);
        }

        LocalDate newDate  = req.getBookingDate();
        LocalTime newStart = req.getStartTime();
        LocalTime newEnd   = newStart.plusMinutes(booking.getService().getDurationMinutes());

        ProviderProfile provider = providerRepo.findByIdForUpdate(booking.getProvider().getId())
                .orElseThrow(() -> new ResourceNotFoundException("Provider", booking.getProvider().getId()));
        requireAcceptingBookings(provider);
        requireBookableSlot(provider, booking.getStaffMember(), booking.getService(), newDate, newStart);
        requireFreeSlot(booking, newDate, newStart);

        booking.setBookingDate(newDate);
        booking.setStartTime(newStart);
        booking.setEndTime(newEnd);
        booking.setProposedDate(null);
        booking.setProposedStartTime(null);
        booking.setProposedAt(null);
        // Reset to PENDING so the provider can re-confirm the new time; their
        // response window starts now, not at the original request (R2-01).
        booking.setStatus(BookingStatus.PENDING);
        booking.setAwaitingSince(LocalDateTime.now());
        booking.setReminderSentAt(null);
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

    /**
     * Tell the right person about a status change. Provider-driven transitions go
     * to the customer; a customer cancellation goes to the provider (before, the
     * customer was notified about their own cancellation and the provider never
     * heard about it).
     */
    private void sendStatusNotification(Booking booking, BookingStatus newStatus, boolean byCustomer) {
        String service = booking.getService().getName();
        if (newStatus == BookingStatus.CANCELLED && byCustomer) {
            notificationService.send(booking.getProvider().getUser().getId(), NotificationType.BOOKING_CANCELLED,
                    "Booking cancelled by customer", "ألغى العميل الحجز",
                    booking.getCustomer().getFullName() + " cancelled " + service + " on " + booking.getBookingDate()
                            + (booking.getCancellationReason() != null ? " — " + booking.getCancellationReason() : ""),
                    booking.getCustomer().getFullName() + " ألغى " + service + " في " + booking.getBookingDate(),
                    booking.getId(), booking.getProvider().getId());
            return;
        }
        NotificationType type = switch (newStatus) {
            case ACCEPTED    -> NotificationType.BOOKING_CONFIRMED;
            case CANCELLED   -> NotificationType.BOOKING_CANCELLED;
            case COMPLETED   -> NotificationType.BOOKING_COMPLETED;
            case REJECTED    -> NotificationType.BOOKING_REJECTED;
            case ON_THE_WAY  -> NotificationType.BOOKING_ON_THE_WAY;
            case ARRIVED     -> NotificationType.BOOKING_ARRIVED;
            case IN_PROGRESS -> NotificationType.BOOKING_STARTED;
            case NO_SHOW     -> NotificationType.BOOKING_NO_SHOW;
            default          -> null;
        };
        if (type == null) return;

        String titleEn = switch (newStatus) {
            case ACCEPTED    -> "Booking confirmed";
            case CANCELLED   -> "Booking cancelled by the provider";
            case COMPLETED   -> "Booking completed";
            case REJECTED    -> "Booking rejected";
            case ON_THE_WAY  -> "Your provider is on the way";
            case ARRIVED     -> "Your provider has arrived";
            case IN_PROGRESS -> "Your service has started";
            case NO_SHOW     -> "Marked as no-show";
            default          -> "Booking updated";
        };
        String titleAr = switch (newStatus) {
            case ACCEPTED    -> "تم تأكيد الحجز";
            case CANCELLED   -> "ألغى المزود الحجز";
            case COMPLETED   -> "اكتمل الحجز";
            case REJECTED    -> "تم رفض الحجز";
            case ON_THE_WAY  -> "مقدم الخدمة في الطريق";
            case ARRIVED     -> "وصل مقدم الخدمة";
            case IN_PROGRESS -> "بدأت خدمتك";
            case NO_SHOW     -> "تم تسجيل عدم الحضور";
            default          -> "تم تحديث الحجز";
        };
        notifyCustomer(booking, type, titleEn, titleAr,
                "Your booking for " + service + " is now " + newStatus.name().toLowerCase().replace('_', ' ')
                        + (newStatus == BookingStatus.CANCELLED && booking.getCancellationReason() != null
                            ? " — " + booking.getCancellationReason() : ""),
                "تم تحديث حجزك لـ " + service);
    }

    private void notifyCustomer(Booking booking, NotificationType type, String titleEn, String titleAr,
                                String bodyEn, String bodyAr) {
        notificationService.send(booking.getCustomer().getId(), type, titleEn, titleAr, bodyEn, bodyAr,
                booking.getId(), booking.getProvider().getId());
    }

    // ── MAPPER ────────────────────────────────────────────────────────────────

    private ApiResponse.BookingDto toDto(Booking b) {
        LocalDateTime proposalExpiresAt = b.getProposedAt() != null && b.getProposedDate() != null
                ? b.getProposedAt().plusMinutes(platformSettings.getResponseWindowMinutes(b.getProvider()))
                : null;
        return ApiResponse.BookingDto.builder()
                .id(b.getId())
                .customer(toCustomerDto(b))
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
                .travelFeeQuote(b.getTravelFeeQuote())
                .travelFeeQuoteStatus(b.getTravelFeeQuoteStatus())
                .completionNote(b.getCompletionNote())
                .notes(b.getNotes())
                .cancellationReason(b.getCancellationReason())
                .cancelledBy(b.getCancelledBy())
                .cancelledAt(b.getCancelledAt())
                .rejectionReason(b.getRejectionReason())
                .proposedDate(b.getProposedDate())
                .proposedStartTime(b.getProposedStartTime())
                .proposalExpiresAt(proposalExpiresAt)
                .penaltyApplied(b.isPenaltyApplied())
                .commissionAmount(b.getCommissionAmount())
                .checkedInAt(b.getCheckedInAt())
                .createdAt(b.getCreatedAt())
                .reviewed(b.getReviews() != null && !b.getReviews().isEmpty())
                .build();
    }

    /**
     * The customer block. Phone and email are only included while the booking is
     * live — a provider shouldn't hold a customer's number for a request they
     * never accepted (or long after the visit).
     */
    private ApiResponse.UserDto toCustomerDto(Booking b) {
        User u = b.getCustomer();
        boolean contact = CONTACT_VISIBLE.contains(b.getStatus());
        return ApiResponse.UserDto.builder().id(u.getId()).fullName(u.getFullName())
                .email(contact ? u.getEmail() : null)
                .phone(contact ? u.getPhone() : null)
                .profileImageUrl(u.getProfileImageUrl())
                .role(u.getRole()).gender(u.getGender()).active(u.isActive()).build();
    }

    private ApiResponse.ProviderSummaryDto toProviderSummary(ProviderProfile p) {
        // The app reads ownerName, category, coordinates and the avatar from here
        // (booking list rows, tracking map) — before, only id/name/address/rating
        // were sent, so the provider name showed blank on booking rows.
        User owner = p.getUser();
        return ApiResponse.ProviderSummaryDto.builder().id(p.getId())
                .businessName(p.getBusinessName())
                .ownerName(owner != null ? owner.getFullName() : null)
                .profileImageUrl(owner != null ? owner.getProfileImageUrl() : null)
                .address(p.getAddress())
                .latitude(p.getLatitude())
                .longitude(p.getLongitude())
                .primaryCategory(p.getPrimaryCategory())
                .providerType(p.getProviderType())
                .averageRating(p.getAverageRating())
                .totalReviews(p.getTotalReviews())
                .verificationStatus(p.getVerificationStatus())
                .verifiedAt(p.getVerifiedAt())
                .build();
    }

    private ApiResponse.ServiceDto toServiceDto(com.aiwa.entity.Service s) {
        return ApiResponse.ServiceDto.builder().id(s.getId()).name(s.getName())
                .price(s.getPrice()).durationMinutes(s.getDurationMinutes())
                .category(s.getCategory())
                .pricingType(s.getPricingType()).transportIncluded(s.isTransportIncluded()).build();
    }

    private ApiResponse.StaffMemberDto toStaffDto(StaffMember s) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
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
