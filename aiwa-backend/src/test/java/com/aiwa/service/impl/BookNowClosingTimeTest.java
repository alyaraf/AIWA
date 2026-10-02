package com.aiwa.service.impl;

import com.aiwa.dto.request.BookingRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import com.aiwa.util.AiwaTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;

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

/**
 * CR-04: Book Now late in the evening used to book a closed provider (the slot
 * arithmetic wrapped past midnight), and the slot list had the same wrap.
 */
class BookNowClosingTimeTest {

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
    private ProviderProfile provider;

    private static final long CUSTOMER_ID = 1L;
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 5);

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
                .durationMinutes(60).active(true).build();

        when(redis.setIfAbsent(any(), any(), any())).thenReturn(true);
        when(userRepo.findById(CUSTOMER_ID)).thenReturn(Optional.of(customer));
        when(providerRepo.findByIdForUpdate(7L)).thenReturn(Optional.of(provider));
        when(serviceRepo.findById(3L)).thenReturn(Optional.of(svc));
        when(bookingRepo.findActiveForCalendar(eq(7L), any(), any())).thenReturn(List.of());
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> {
            Booking b = inv.getArgument(0);
            b.setId(999L);
            return b;
        });
    }

    private void workingHours(LocalTime from, LocalTime to) {
        when(availabilityRepo.findByProviderIdAndStaffMemberIsNullAndDayOfWeek(eq(7L), any()))
                .thenReturn(Optional.of(Availability.builder().provider(provider)
                        .startTime(from).endTime(to).slotDurationMinutes(30).available(true).build()));
    }

    private static BookingRequest bookNow() {
        BookingRequest req = new BookingRequest();
        req.setProviderId(7L);
        req.setServiceId(3L);
        req.setBookingType(BookingType.BOOK_NOW);
        return req;
    }

    /** Runs Book Now with the Cairo clock set to {@code time} on {@link #TODAY}. */
    private ApiResponse.BookingDto bookNowAt(LocalTime time) {
        try (MockedStatic<AiwaTime> clock = mockStatic(AiwaTime.class)) {
            clock.when(AiwaTime::today).thenReturn(TODAY);
            clock.when(AiwaTime::timeNow).thenReturn(time);
            clock.when(AiwaTime::now).thenReturn(LocalDateTime.of(TODAY, time));
            return service.create(CUSTOMER_ID, bookNow());
        }
    }

    @Test
    void bookNowAfterClosingBooksNothing() {
        workingHours(LocalTime.of(9, 0), LocalTime.of(17, 0));

        // 23:10, a 60-minute service: used to give a PENDING booking 23:30–00:30.
        assertThatThrownBy(() -> bookNowAt(LocalTime.of(23, 10)))
                .isInstanceOf(BusinessException.class).hasMessageContaining("no_book_now_slots");
        verify(bookingRepo, never()).save(any(Booking.class));

        // During the day it still takes the next slot.
        ApiResponse.BookingDto dto = bookNowAt(LocalTime.of(10, 7));
        assertThat(dto.getStartTime()).isEqualTo(LocalTime.of(10, 30));
        assertThat(dto.getEndTime()).isEqualTo(LocalTime.of(11, 30));
    }

    @Test
    void bookNowNeverTakesASlotThatEndsPastMidnight() {
        workingHours(LocalTime.of(20, 0), LocalTime.of(23, 30));

        // 22:40: the next slot is 23:00, and 23:00 + 60 min is past closing (and past midnight).
        assertThatThrownBy(() -> bookNowAt(LocalTime.of(22, 40)))
                .isInstanceOf(BusinessException.class).hasMessageContaining("no_book_now_slots");
        verify(bookingRepo, never()).save(any(Booking.class));
    }

    @Test
    void theSlotListHasNoSlotThatWrapsPastMidnight() {
        workingHours(LocalTime.of(20, 0), LocalTime.of(23, 30));
        List<ApiResponse.TimeSlotDto> late = service.getAvailableSlots(7L, 3L, null, LocalDate.now().plusDays(1));

        assertThat(late).allSatisfy(s -> assertThat(s.getEndTime()).isAfter(s.getStartTime()));
        assertThat(late).extracting(ApiResponse.TimeSlotDto::getStartTime)
                .containsExactly(LocalTime.of(20, 0), LocalTime.of(20, 30), LocalTime.of(21, 0),
                        LocalTime.of(21, 30), LocalTime.of(22, 0), LocalTime.of(22, 30));

        workingHours(LocalTime.of(9, 0), LocalTime.of(17, 0));
        List<ApiResponse.TimeSlotDto> day = service.getAvailableSlots(7L, 3L, null, LocalDate.now().plusDays(1));
        assertThat(day).hasSize(15);
        assertThat(day.get(14).getEndTime()).isEqualTo(LocalTime.of(17, 0));
    }
}
