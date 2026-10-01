package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class BookingPaymentAndStaffTest {

    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final ServiceRepository serviceRepo = mock(ServiceRepository.class);
    private final AvailabilityRepository availabilityRepo = mock(AvailabilityRepository.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final StaffMemberRepository staffRepo = mock(StaffMemberRepository.class);
    private final SavedAddressRepository savedAddressRepo = mock(SavedAddressRepository.class);
    private final CommissionLedgerRepository commissionLedgerRepo = mock(CommissionLedgerRepository.class);
    private final PlatformSettingsServiceImpl platformSettings = mock(PlatformSettingsServiceImpl.class);
    private final RedisRuntimeService redis = mock(RedisRuntimeService.class);

    private BookingServiceImpl service;

    private static final long PROVIDER_USER_ID = 100L;
    private static final long CUSTOMER_ID = 200L;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl(bookingRepo, userRepo, providerRepo, serviceRepo,
                availabilityRepo, notificationService, staffRepo, savedAddressRepo, commissionLedgerRepo,
                platformSettings, redis);
        when(redis.setIfAbsent(any(), any(), any())).thenReturn(true);
        when(platformSettings.getResponseWindowMinutes()).thenReturn(120L);
        when(platformSettings.getResponseWindowMinutes(any())).thenReturn(120L);
        when(platformSettings.getCommissionPercent()).thenReturn(new BigDecimal("10"));
        when(platformSettings.getCommissionPercentFor(any())).thenReturn(new BigDecimal("10"));
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private ProviderProfile provider() {
        User provUser = User.builder().id(PROVIDER_USER_ID).fullName("Prov").role(UserRole.PROVIDER).build();
        return ProviderProfile.builder().id(7L).user(provUser).build();
    }

    private Booking completedBooking(ProviderProfile provider) {
        User customer = User.builder().id(CUSTOMER_ID).fullName("Cust").role(UserRole.CUSTOMER).build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).name("Haircut").durationMinutes(30).price(new BigDecimal("100")).provider(provider).build();
        return Booking.builder().id(55L).customer(customer).provider(provider).service(svc)
                .status(BookingStatus.COMPLETED).totalPrice(new BigDecimal("100"))
                .paymentStatus(PaymentStatus.CASH_PENDING)
                .bookingDate(LocalDate.now()).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .build();
    }

    // ── Customer payment confirm / dispute ──────────────────────────────────────

    @Test
    void customerConfirmsCashPaid() {
        Booking b = completedBooking(provider());
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(commissionLedgerRepo.existsByBookingId(55L)).thenReturn(false);

        ApiResponse.BookingDto dto = service.confirmPayment(CUSTOMER_ID, 55L, true);

        assertThat(dto.getPaymentStatus()).isEqualTo(PaymentStatus.CASH_CONFIRMED);
        verify(commissionLedgerRepo).save(any(CommissionLedgerEntry.class));
    }

    @Test
    void customerReportsDispute() {
        Booking b = completedBooking(provider());
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(userRepo.findByRoleAndActive(UserRole.ADMIN, true))
                .thenReturn(List.of(User.builder().id(1L).role(UserRole.ADMIN).active(true).build()));

        ApiResponse.BookingDto dto = service.confirmPayment(CUSTOMER_ID, 55L, false);

        assertThat(dto.getPaymentStatus()).isEqualTo(PaymentStatus.DISPUTED);
        verify(commissionLedgerRepo, never()).save(any());
    }

    @Test
    void onlyCustomerCanConfirmPayment() {
        Booking b = completedBooking(provider());
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        assertThatThrownBy(() -> service.confirmPayment(PROVIDER_USER_ID, 55L, true))
                .isInstanceOf(BusinessException.class).hasMessageContaining("only_customer_confirm_payment");
    }

    @Test
    void cannotConfirmPaymentBeforeCompletion() {
        Booking b = completedBooking(provider());
        b.setStatus(BookingStatus.IN_PROGRESS);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        assertThatThrownBy(() -> service.confirmPayment(CUSTOMER_ID, 55L, true))
                .isInstanceOf(BusinessException.class).hasMessageContaining("completed");
    }

    // ── Venue check-in ──────────────────────────────────────────────────────────

    @Test
    void customerChecksInAtVenue() {
        Booking b = completedBooking(provider());
        b.setStatus(BookingStatus.ACCEPTED);
        b.setHomeService(false);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        ApiResponse.BookingDto dto = service.checkIn(CUSTOMER_ID, 55L);

        assertThat(b.getCheckedInAt()).isNotNull();
        assertThat(dto.getCheckedInAt()).isNotNull();
        verify(notificationService).send(eq(PROVIDER_USER_ID), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void checkInRejectedForHomeService() {
        Booking b = completedBooking(provider());
        b.setStatus(BookingStatus.ACCEPTED);
        b.setHomeService(true);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        assertThatThrownBy(() -> service.checkIn(CUSTOMER_ID, 55L))
                .isInstanceOf(BusinessException.class).hasMessageContaining("checkin_onsite_only");
    }

    @Test
    void checkInRejectedWhenNotAccepted() {
        Booking b = completedBooking(provider()); // status COMPLETED
        b.setHomeService(false);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        assertThatThrownBy(() -> service.checkIn(CUSTOMER_ID, 55L))
                .isInstanceOf(BusinessException.class).hasMessageContaining("accepted");
    }

    // ── Admin overrides ─────────────────────────────────────────────────────────

    @Test
    void adminForceCancelsActiveBooking() {
        Booking b = completedBooking(provider());
        b.setStatus(BookingStatus.ACCEPTED);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        ApiResponse.BookingDto dto = service.adminForceCancel(55L, "Fraudulent booking");

        assertThat(dto.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(b.getCancelledBy()).isEqualTo("ADMIN");
        assertThat(b.getCancellationReason()).isEqualTo("Fraudulent booking");
    }

    @Test
    void adminCannotForceCancelClosedBooking() {
        Booking b = completedBooking(provider()); // COMPLETED
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        assertThatThrownBy(() -> service.adminForceCancel(55L, "x"))
                .isInstanceOf(BusinessException.class).hasMessageContaining("already closed");
    }

    @Test
    void adminResolvesDisputeAsPaid() {
        Booking b = completedBooking(provider());
        b.setPaymentStatus(PaymentStatus.DISPUTED);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(commissionLedgerRepo.existsByBookingId(55L)).thenReturn(false);

        ApiResponse.BookingDto dto = service.adminResolveDispute(55L, true);

        assertThat(dto.getPaymentStatus()).isEqualTo(PaymentStatus.CASH_CONFIRMED);
        verify(commissionLedgerRepo).save(any(CommissionLedgerEntry.class));
    }

    @Test
    void adminResolvesDisputeAsWriteOff() {
        Booking b = completedBooking(provider());
        b.setPaymentStatus(PaymentStatus.DISPUTED);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        ApiResponse.BookingDto dto = service.adminResolveDispute(55L, false);

        assertThat(dto.getPaymentStatus()).isEqualTo(PaymentStatus.UNPAID);
        verify(commissionLedgerRepo, never()).save(any());
    }

    @Test
    void resolveDisputeRejectsNonDisputed() {
        Booking b = completedBooking(provider());
        b.setPaymentStatus(PaymentStatus.CASH_CONFIRMED);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        assertThatThrownBy(() -> service.adminResolveDispute(55L, true))
                .isInstanceOf(BusinessException.class).hasMessageContaining("not_disputed");
    }

    // ── Per-staff slot scoping ──────────────────────────────────────────────────

    @Test
    void slotsUseStaffCalendarWhenStaffPicked() {
        ProviderProfile provider = provider();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).name("Haircut").durationMinutes(30).provider(provider).build();
        when(serviceRepo.findById(3L)).thenReturn(Optional.of(svc));

        Availability staffAvail = Availability.builder()
                .provider(provider).dayOfWeek(DayOfWeek.MONDAY)
                .startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(11, 0))
                .slotDurationMinutes(30).available(true).build();
        when(availabilityRepo.findByProviderIdAndStaffMemberIdAndDayOfWeek(eq(7L), eq(9L), any(DayOfWeek.class)))
                .thenReturn(Optional.of(staffAvail));
        when(bookingRepo.findActiveForCalendar(eq(7L), any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        // Tomorrow: slots that already started today are reported as taken.
        List<ApiResponse.TimeSlotDto> slots = service.getAvailableSlots(7L, 3L, 9L, LocalDate.now().plusDays(1));

        assertThat(slots).hasSize(2);
        assertThat(slots).allSatisfy(s -> assertThat(s.isBooked()).isFalse());
        // One query for the shop's calendar (staff + unassigned bookings, DR-023).
        verify(bookingRepo).findActiveForCalendar(eq(7L), any(LocalDate.class), any(LocalDate.class));
    }
}
