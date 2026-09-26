package com.aiwa.service.impl;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * The provider sets a flat home-service travel fee on their profile. When the
 * customer books a home service, that fee is snapshotted onto the booking and
 * added to the total. Non-home bookings ignore it. Commission is charged on
 * the service portion only — the travel money is pass-through to the provider
 * (they're covering Uber out of it, the platform doesn't skim it).
 */
class BookingHomeServiceTravelFeeTest {

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

    private static final long CUSTOMER_ID = 1L;
    private ProviderProfile provider;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl(bookingRepo, userRepo, providerRepo, serviceRepo,
                availabilityRepo, notificationService, staffRepo, savedAddressRepo, commissionLedgerRepo,
                platformSettings, redis);

        User customer = User.builder().id(CUSTOMER_ID).fullName("Nour").role(UserRole.CUSTOMER).build();
        User providerUser = User.builder().id(50L).fullName("Nadia").role(UserRole.PROVIDER).build();
        provider = ProviderProfile.builder().id(7L).user(providerUser)
                .verificationStatus(VerificationStatus.APPROVED)
                .vacationMode(false).offlineMode(false).settlementPaused(false)
                .travelBufferMinutes(0)
                .build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).provider(provider).name("Haircut").price(new BigDecimal("100"))
                .durationMinutes(30).active(true).build();

        when(userRepo.findById(CUSTOMER_ID)).thenReturn(Optional.of(customer));
        when(providerRepo.findById(7L)).thenReturn(Optional.of(provider));
        when(serviceRepo.findById(3L)).thenReturn(Optional.of(svc));
        when(bookingRepo.existsConflict(anyLong(), any(), any(), any())).thenReturn(false);
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> {
            Booking b = inv.getArgument(0);
            if (b.getId() == null) b.setId(999L);
            return b;
        });
        when(redis.setIfAbsent(any(), any(), any())).thenReturn(true);
        when(platformSettings.getCommissionPercentFor(any())).thenReturn(new BigDecimal("10"));
    }

    private BookingRequest homeRequest(boolean home) {
        BookingRequest req = new BookingRequest();
        req.setProviderId(7L);
        req.setServiceId(3L);
        req.setBookingType(BookingType.SCHEDULED);
        req.setBookingDate(LocalDate.now().plusDays(1));
        req.setStartTime(LocalTime.of(10, 0));
        req.setHomeService(home);
        return req;
    }

    @Test
    void homeServiceBookingPicksUpTheProvidersTravelFeeAndAddsItToTheTotal() {
        provider.setHomeServiceTravelFee(new BigDecimal("150.00"));

        ApiResponse.BookingDto dto = service.create(CUSTOMER_ID, homeRequest(true), "k-home-with-fee");

        assertThat(dto.getTravelFee()).isEqualByComparingTo("150.00");
        assertThat(dto.getTotalPrice()).isEqualByComparingTo("250.00"); // 100 service + 150 travel
        assertThat(dto.isHomeService()).isTrue();
    }

    @Test
    void homeServiceBookingWithNoProviderFeeLeavesTravelFeeNull() {
        provider.setHomeServiceTravelFee(null);

        ApiResponse.BookingDto dto = service.create(CUSTOMER_ID, homeRequest(true), "k-home-no-fee");

        assertThat(dto.getTravelFee()).isNull();
        assertThat(dto.getTotalPrice()).isEqualByComparingTo("100.00");
        assertThat(dto.isHomeService()).isTrue();
    }

    @Test
    void zeroTravelFeeIsTreatedAsAbsentNotChargedAsAZeroLineItem() {
        provider.setHomeServiceTravelFee(BigDecimal.ZERO);

        ApiResponse.BookingDto dto = service.create(CUSTOMER_ID, homeRequest(true), "k-home-zero-fee");

        // 0 EGP travel = provider covers travel; a receipt line saying "travel: 0"
        // is misleading noise, so we store null and the UI simply omits the line.
        assertThat(dto.getTravelFee()).isNull();
        assertThat(dto.getTotalPrice()).isEqualByComparingTo("100.00");
    }

    @Test
    void nonHomeServiceBookingIgnoresProviderTravelFeeEvenWhenSet() {
        provider.setHomeServiceTravelFee(new BigDecimal("150.00"));

        ApiResponse.BookingDto dto = service.create(CUSTOMER_ID, homeRequest(false), "k-onsite");

        assertThat(dto.getTravelFee()).isNull();
        assertThat(dto.getTotalPrice()).isEqualByComparingTo("100.00");
        assertThat(dto.isHomeService()).isFalse();
    }

    @Test
    void commissionIsChargedOnServicePortionOnlyNotOnTravelFee() {
        // Set up a completed home-service booking with a travel fee to prove the
        // ledger entry commissions only the service portion, not the pass-through
        // travel money.
        Booking completed = Booking.builder()
                .id(555L)
                .customer(User.builder().id(CUSTOMER_ID).fullName("Nour").build())
                .provider(provider)
                .service(com.aiwa.entity.Service.builder().id(3L).name("Haircut").price(new BigDecimal("100")).build())
                .status(BookingStatus.COMPLETED)
                .totalPrice(new BigDecimal("250.00"))    // service 100 + travel 150
                .travelFee(new BigDecimal("150.00"))
                .paymentStatus(PaymentStatus.CASH_CONFIRMED)
                .bookingDate(LocalDate.now().minusDays(1))
                .startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .homeService(true)
                .build();
        when(bookingRepo.findById(555L)).thenReturn(Optional.of(completed));
        when(commissionLedgerRepo.existsByBookingId(555L)).thenReturn(false);

        // Trigger commission recording by simulating what happens after payment
        // confirms — reflectively call the private recordCommissionIfNeeded, since
        // that's the one bit of behaviour we're pinning here.
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(
                service, "recordCommissionIfNeeded", completed);

        ArgumentCaptor<CommissionLedgerEntry> captor = ArgumentCaptor.forClass(CommissionLedgerEntry.class);
        verify(commissionLedgerRepo).save(captor.capture());
        CommissionLedgerEntry entry = captor.getValue();

        // 10% of 100 (service portion), NOT 10% of 250 (total). Travel is
        // pass-through — provider keeps all 150 to pay Uber.
        assertThat(entry.getCommissionAmount()).isEqualByComparingTo("10.00");
        // But the ledger still records the true booking total for auditability.
        assertThat(entry.getBookingAmount()).isEqualByComparingTo("250.00");
    }

    @Test
    void commissionOnAPlainOnsiteBookingIsUnchangedByTheNewLogic() {
        Booking completed = Booking.builder()
                .id(556L)
                .customer(User.builder().id(CUSTOMER_ID).build())
                .provider(provider)
                .service(com.aiwa.entity.Service.builder().id(3L).name("Haircut").price(new BigDecimal("100")).build())
                .status(BookingStatus.COMPLETED)
                .totalPrice(new BigDecimal("100"))
                .travelFee(null) // onsite → no travel fee
                .paymentStatus(PaymentStatus.CASH_CONFIRMED)
                .bookingDate(LocalDate.now().minusDays(1))
                .startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .homeService(false)
                .build();
        when(bookingRepo.findById(556L)).thenReturn(Optional.of(completed));

        org.springframework.test.util.ReflectionTestUtils.invokeMethod(
                service, "recordCommissionIfNeeded", completed);

        ArgumentCaptor<CommissionLedgerEntry> captor = ArgumentCaptor.forClass(CommissionLedgerEntry.class);
        verify(commissionLedgerRepo).save(captor.capture());
        assertThat(captor.getValue().getCommissionAmount()).isEqualByComparingTo("10.00"); // 10% of 100
    }
}
