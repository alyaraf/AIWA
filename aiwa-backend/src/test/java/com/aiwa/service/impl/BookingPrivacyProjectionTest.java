package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ProviderType;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Audit B-02 / B-03: which audience sees which provider location / customer contact in which booking state. */
class BookingPrivacyProjectionTest {

    private static final long PROVIDER_USER_ID = 100L, CUSTOMER_ID = 200L;
    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final PlatformSettingsServiceImpl platformSettings = mock(PlatformSettingsServiceImpl.class);
    private BookingServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl(bookingRepo, mock(UserRepository.class), mock(ProviderProfileRepository.class),
                mock(ServiceRepository.class), mock(AvailabilityRepository.class), mock(NotificationServiceImpl.class),
                mock(StaffMemberRepository.class), mock(SavedAddressRepository.class),
                mock(CommissionLedgerRepository.class), platformSettings, mock(RedisRuntimeService.class));
        when(platformSettings.getResponseWindowMinutes(any())).thenReturn(120L);
    }

    private Booking booking(ProviderType type, BookingStatus status) {
        User provUser = User.builder().id(PROVIDER_USER_ID).fullName("Prov").role(UserRole.PROVIDER).build();
        ProviderProfile provider = ProviderProfile.builder().id(7L).user(provUser).businessName("Home Beauty")
                .providerType(type).address("12 Secret Street").latitude(30.04412).longitude(31.23581).build();
        User customer = User.builder().id(CUSTOMER_ID).fullName("Cust").email("cust@example.test")
                .phone("+201000000001").role(UserRole.CUSTOMER).active(true).build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder().id(3L).name("Cut").durationMinutes(30)
                .price(new BigDecimal("100")).provider(provider).build();
        Booking b = Booking.builder().id(55L).customer(customer).provider(provider).service(svc).status(status)
                .totalPrice(new BigDecimal("100")).bookingDate(LocalDate.now()).startTime(LocalTime.of(10, 0))
                .endTime(LocalTime.of(10, 30)).build();
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));
        when(bookingRepo.countByCustomerId(CUSTOMER_ID)).thenReturn(1L);
        return b;
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void aHomeProvidersExactLocationIsOnlyShownToTheCustomerWhileTheVisitIsLive(BookingStatus status) {
        booking(ProviderType.INDIVIDUAL, status);
        ApiResponse.ProviderSummaryDto p = service.getById(55L, CUSTOMER_ID).getProvider();
        if (BookingServiceImpl.CONTACT_VISIBLE.contains(status)) {
            assertThat(p.getAddress()).isEqualTo("12 Secret Street");
            assertThat(p.getLatitude()).isEqualTo(30.04412);
        } else {
            assertThat(p.getAddress()).as("address in " + status).isNull();
            assertThat(p.getLatitude()).as("rounded to the ~500 m grid").isEqualTo(30.045);
            assertThat(p.getLongitude()).isEqualTo(31.235);
        }
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void aVenueKeepsItsExactAddressInEveryState(BookingStatus status) {
        booking(ProviderType.SHOP, status);
        ApiResponse.ProviderSummaryDto p = service.getById(55L, CUSTOMER_ID).getProvider();
        assertThat(p.getAddress()).isEqualTo("12 Secret Street");
        assertThat(p.getLatitude()).isEqualTo(30.04412);
    }

    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void theProviderSeesTheCustomersContactOnlyWhileTheVisitIsLive(BookingStatus status) {
        booking(ProviderType.INDIVIDUAL, status);
        ApiResponse.UserDto c = service.getById(55L, PROVIDER_USER_ID).getCustomer();
        if (BookingServiceImpl.CONTACT_VISIBLE.contains(status)) {
            assertThat(c.getPhone()).isEqualTo("+201000000001");
            assertThat(c.getEmail()).isEqualTo("cust@example.test");
        } else {
            assertThat(c.getPhone()).as("phone in " + status).isNull();
            assertThat(c.getEmail()).isNull();
        }
    }

    @Test
    void privacyPolicyTreatsAnUnknownStatusAsNotVisible() {
        assertThat(BookingPrivacy.contactVisible(null)).isFalse();
    }

    /** B-03: the provider dashboard used to copy email/phone for every state. */
    @ParameterizedTest
    @EnumSource(BookingStatus.class)
    void theProviderDashboardUsesTheSameContactRule(BookingStatus status) {
        Booking b = booking(ProviderType.INDIVIDUAL, status);
        b.setBookingDate(com.aiwa.util.AiwaTime.today());
        ProviderProfileRepository providers = mock(ProviderProfileRepository.class);
        when(providers.findByUserId(PROVIDER_USER_ID)).thenReturn(Optional.of(b.getProvider()));
        when(bookingRepo.findByProviderIdAndBookingDate(7L, com.aiwa.util.AiwaTime.today()))
                .thenReturn(java.util.List.of(b));
        ProviderServiceImpl provider = new ProviderServiceImpl(providers, mock(UserRepository.class), bookingRepo,
                mock(ServiceRepository.class), mock(AvailabilityRepository.class), mock(RedisRuntimeService.class));

        ApiResponse.UserDto c = provider.getDashboard(PROVIDER_USER_ID).getTodayBookings().get(0).getCustomer();

        boolean live = BookingServiceImpl.CONTACT_VISIBLE.contains(status);
        assertThat(c.getPhone()).as("phone in " + status).isEqualTo(live ? "+201000000001" : null);
        assertThat(c.getEmail()).as("email in " + status).isEqualTo(live ? "cust@example.test" : null);
    }
}
