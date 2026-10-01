package com.aiwa.service.impl;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * A double-tap (or a client retry after a dropped response) must not create
 * two bookings. Covers both the explicit Idempotency-Key path and the
 * automatic same-content guard used when the client doesn't send one.
 */
class BookingIdempotencyTest {

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
    private static final long PROVIDER_USER_ID = 50L;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl(bookingRepo, userRepo, providerRepo, serviceRepo,
                availabilityRepo, notificationService, staffRepo, savedAddressRepo, commissionLedgerRepo,
                platformSettings, redis);

        User customer = User.builder().id(CUSTOMER_ID).fullName("Nour").role(UserRole.CUSTOMER).build();
        User providerUser = User.builder().id(PROVIDER_USER_ID).fullName("Nadia").role(UserRole.PROVIDER).build();
        ProviderProfile provider = ProviderProfile.builder().id(7L).user(providerUser)
                .verificationStatus(VerificationStatus.APPROVED)
                .vacationMode(false).offlineMode(false).settlementPaused(false)
                .travelBufferMinutes(0)
                .build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).provider(provider).name("Haircut").price(new BigDecimal("100"))
                .durationMinutes(30).active(true).build();

        when(userRepo.findById(CUSTOMER_ID)).thenReturn(Optional.of(customer));
        when(providerRepo.findById(7L)).thenReturn(Optional.of(provider));
        when(providerRepo.findByIdForUpdate(7L)).thenReturn(Optional.of(provider));
        when(availabilityRepo.findByProviderIdAndStaffMemberIsNullAndDayOfWeek(eq(7L), any()))
                .thenReturn(Optional.of(com.aiwa.entity.Availability.builder().provider(provider)
                        .startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(22, 0))
                        .slotDurationMinutes(30).available(true).build()));
        when(serviceRepo.findById(3L)).thenReturn(Optional.of(svc));
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> {
            Booking b = inv.getArgument(0);
            b.setId(999L);
            return b;
        });
    }

    private BookingRequest request() {
        BookingRequest req = new BookingRequest();
        req.setProviderId(7L);
        req.setServiceId(3L);
        req.setBookingType(BookingType.SCHEDULED);
        req.setBookingDate(LocalDate.now().plusDays(1));
        req.setStartTime(LocalTime.of(10, 0));
        return req;
    }

    @Test
    void explicitKeyReplayReturnsSameBookingWithoutCreatingANewOne() {
        when(redis.setIfAbsent(eq("idem:booking:1:tap-1"), eq("pending"), any())).thenReturn(true, false);
        when(redis.get("idem:booking:1:tap-1")).thenReturn(Optional.of("999"));
        when(bookingRepo.findById(999L)).thenAnswer(inv -> Optional.of(
                Booking.builder().id(999L).customer(User.builder().id(CUSTOMER_ID).build())
                        .provider(ProviderProfile.builder().id(7L).build())
                        .service(com.aiwa.entity.Service.builder().id(3L).name("Haircut").price(new BigDecimal("100")).build())
                        .status(BookingStatus.PENDING).totalPrice(new BigDecimal("100"))
                        .bookingDate(LocalDate.now().plusDays(1)).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                        .build()));

        ApiResponse.BookingDto first = service.create(CUSTOMER_ID, request(), "tap-1");
        ApiResponse.BookingDto retry = service.create(CUSTOMER_ID, request(), "tap-1");

        assertThat(first.getId()).isEqualTo(999L);
        assertThat(retry.getId()).isEqualTo(999L);
        verify(bookingRepo, times(1)).save(any(Booking.class)); // only the first call actually created anything
    }

    @Test
    void concurrentRequestStillInFlightIsRejectedNotDuplicated() {
        when(redis.setIfAbsent(anyString(), eq("pending"), any())).thenReturn(false);
        when(redis.get(anyString())).thenReturn(Optional.of("pending"));

        assertThatThrownBy(() -> service.create(CUSTOMER_ID, request(), "tap-2"))
                .isInstanceOf(BusinessException.class)
                .hasMessage("booking.error.duplicate");
        verify(bookingRepo, never()).save(any());
    }

    @Test
    void noExplicitKeyStillDedupsIdenticalRequestAutomatically() {
        // Same request content twice, no Idempotency-Key header from the client —
        // the auto-derived fingerprint key should still catch the double-tap.
        when(redis.setIfAbsent(startsWith("idem:booking:1:auto:"), eq("pending"), any()))
                .thenReturn(true, false);
        when(redis.get(startsWith("idem:booking:1:auto:"))).thenReturn(Optional.of("999"));
        when(bookingRepo.findById(999L)).thenAnswer(inv -> Optional.of(
                Booking.builder().id(999L).customer(User.builder().id(CUSTOMER_ID).build())
                        .provider(ProviderProfile.builder().id(7L).build())
                        .service(com.aiwa.entity.Service.builder().id(3L).name("Haircut").price(new BigDecimal("100")).build())
                        .status(BookingStatus.PENDING).totalPrice(new BigDecimal("100"))
                        .bookingDate(LocalDate.now().plusDays(1)).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                        .build()));

        service.create(CUSTOMER_ID, request(), null);
        service.create(CUSTOMER_ID, request(), null);

        verify(bookingRepo, times(1)).save(any(Booking.class));
    }

    @Test
    void aRejectedRequestReleasesItsClaimSoARetryCanSucceed() {
        when(redis.setIfAbsent(anyString(), eq("pending"), any())).thenReturn(true);
        when(serviceRepo.findById(3L)).thenReturn(Optional.of(
                com.aiwa.entity.Service.builder().id(3L)
                        .provider(ProviderProfile.builder().id(7L).build())
                        .name("Haircut").price(new BigDecimal("100")).durationMinutes(30)
                        .active(false) // inactive → doCreate throws
                        .build()));

        assertThatThrownBy(() -> service.create(CUSTOMER_ID, request(), "tap-3"))
                .isInstanceOf(BusinessException.class);

        verify(redis).delete("idem:booking:1:tap-3");
    }

    @Test
    void bookingStillSucceedsWhenRedisIsUnreachable() {
        // The dedup guard is a convenience on top of the real slot-conflict check —
        // it must not turn a Redis outage into "nobody can book anything".
        when(redis.setIfAbsent(anyString(), eq("pending"), any())).thenThrow(new RuntimeException("Connection refused"));

        ApiResponse.BookingDto dto = service.create(CUSTOMER_ID, request(), "tap-4");

        assertThat(dto.getId()).isEqualTo(999L);
        verify(bookingRepo).save(any(Booking.class));
    }
}
