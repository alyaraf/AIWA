package com.aiwa.service.impl;

import com.aiwa.dto.request.RescheduleRequest;
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
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Covers the booking-lifecycle fixes: auto-expiry, dispute completion, and provider-proposed reschedule. */
class BookingLifecycleServiceTest {

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

    private Booking booking(BookingStatus status) {
        User provUser = User.builder().id(PROVIDER_USER_ID).fullName("Prov").role(UserRole.PROVIDER).build();
        ProviderProfile provider = ProviderProfile.builder().id(7L).user(provUser).build();
        User customer = User.builder().id(CUSTOMER_ID).fullName("Cust").role(UserRole.CUSTOMER).build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).name("Haircut").durationMinutes(30).price(new BigDecimal("100")).provider(provider).build();
        return Booking.builder()
                .id(55L).customer(customer).provider(provider).service(svc)
                .status(status).totalPrice(new BigDecimal("100"))
                .bookingDate(LocalDate.now().plusDays(1)).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .build();
    }

    // ── Auto-expiry ────────────────────────────────────────────────────────────

    @Test
    void expiresStalePendingBookingsAndNotifiesBothParties() {
        Booking stale = booking(BookingStatus.PENDING);
        stale.setCreatedAt(LocalDateTime.now().minusHours(5));
        when(bookingRepo.findByStatus(BookingStatus.PENDING)).thenReturn(List.of(stale));

        int count = service.expireStalePendingBookings();

        assertThat(count).isEqualTo(1);
        assertThat(stale.getStatus()).isEqualTo(BookingStatus.EXPIRED);
        verify(bookingRepo).save(stale);
        verify(notificationService, times(2)).send(anyLong(), any(), any(), any(), any(), any(), any(), any());
    }

    // ── Completion payment branch ────────────────────────────────────────────────

    @Test
    void completeWithCashConfirmsAndRecordsCommission() {
        Booking b = booking(BookingStatus.IN_PROGRESS);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(commissionLedgerRepo.existsByBookingId(55L)).thenReturn(false);

        ApiResponse.BookingDto dto = service.complete(PROVIDER_USER_ID, 55L, true);

        assertThat(dto.getStatus()).isEqualTo(BookingStatus.COMPLETED);
        assertThat(b.getPaymentStatus()).isEqualTo(PaymentStatus.CASH_CONFIRMED);
        verify(commissionLedgerRepo).save(any(CommissionLedgerEntry.class));
    }

    @Test
    void completeWithoutCashFlagsDisputedAndNotifiesAdmins_noCommission() {
        Booking b = booking(BookingStatus.IN_PROGRESS);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        User admin = User.builder().id(1L).role(UserRole.ADMIN).active(true).build();
        when(userRepo.findByRoleAndActive(UserRole.ADMIN, true)).thenReturn(List.of(admin));

        ApiResponse.BookingDto dto = service.complete(PROVIDER_USER_ID, 55L, false);

        assertThat(dto.getStatus()).isEqualTo(BookingStatus.COMPLETED);
        assertThat(b.getPaymentStatus()).isEqualTo(PaymentStatus.DISPUTED);
        verify(commissionLedgerRepo, never()).save(any());
        verify(notificationService).send(eq(1L), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void onlyProviderCanComplete() {
        Booking b = booking(BookingStatus.IN_PROGRESS);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        assertThatThrownBy(() -> service.complete(CUSTOMER_ID, 55L, true))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("only_provider_complete");
    }

    // ── Provider proposes alternative time ───────────────────────────────────────

    @Test
    void providerProposesTime_thenCustomerAccepts() {
        Booking b = booking(BookingStatus.PENDING);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(bookingRepo.existsConflict(anyLong(), any(), any(), any())).thenReturn(false);

        RescheduleRequest req = new RescheduleRequest();
        req.setBookingDate(LocalDate.now().plusDays(2));
        req.setStartTime(LocalTime.of(14, 0));

        service.proposeReschedule(PROVIDER_USER_ID, 55L, req);
        assertThat(b.getProposedDate()).isEqualTo(LocalDate.now().plusDays(2));
        assertThat(b.getProposedStartTime()).isEqualTo(LocalTime.of(14, 0));
        assertThat(b.getStatus()).isEqualTo(BookingStatus.PENDING);

        service.respondToProposal(CUSTOMER_ID, 55L, true);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.ACCEPTED);
        assertThat(b.getStartTime()).isEqualTo(LocalTime.of(14, 0));
        assertThat(b.getBookingDate()).isEqualTo(LocalDate.now().plusDays(2));
        assertThat(b.getProposedStartTime()).isNull();
    }

    @Test
    void customerDeclinesProposedTime() {
        Booking b = booking(BookingStatus.PENDING);
        b.setProposedDate(LocalDate.now().plusDays(2));
        b.setProposedStartTime(LocalTime.of(14, 0));
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        service.respondToProposal(CUSTOMER_ID, 55L, false);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.REJECTED);
        assertThat(b.getProposedStartTime()).isNull();
    }

    @Test
    void onlyProviderCanProposeTime() {
        Booking b = booking(BookingStatus.PENDING);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        RescheduleRequest req = new RescheduleRequest();
        req.setBookingDate(LocalDate.now().plusDays(2));
        req.setStartTime(LocalTime.of(14, 0));

        assertThatThrownBy(() -> service.proposeReschedule(CUSTOMER_ID, 55L, req))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("only_provider_propose");
    }
}
