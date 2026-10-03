package com.aiwa.service.impl;

import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import com.aiwa.util.AiwaTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.zone.ZoneOffsetTransition;
import java.util.List;
import java.util.Optional;
import java.util.TimeZone;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.CALLS_REAL_METHODS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.when;

/**
 * CR-13(f): the response window and the cancellation cut-off are lengths of
 * real time. Compared as wall-clock times they were an hour off on the two
 * nights the clocks change (Africa/Cairo: 00:00 → 01:00 in April, 24:00 → 23:00
 * in October).
 */
class BookingDstNightTest {

    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final PlatformSettingsServiceImpl platformSettings = mock(PlatformSettingsServiceImpl.class);

    private BookingServiceImpl service;

    private static final long PROVIDER_USER_ID = 100L;
    private static final long CUSTOMER_ID = 200L;

    @BeforeEach
    void setUp() {
        service = new BookingServiceImpl(bookingRepo, mock(UserRepository.class), mock(ProviderProfileRepository.class),
                mock(ServiceRepository.class), mock(AvailabilityRepository.class), mock(NotificationServiceImpl.class),
                mock(StaffMemberRepository.class), mock(SavedAddressRepository.class),
                mock(CommissionLedgerRepository.class), platformSettings, mock(RedisRuntimeService.class));
        when(bookingRepo.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Booking booking(BookingStatus status, LocalDateTime start) {
        User provUser = User.builder().id(PROVIDER_USER_ID).fullName("Prov").role(UserRole.PROVIDER).build();
        ProviderProfile provider = ProviderProfile.builder().id(7L).user(provUser).build();
        User customer = User.builder().id(CUSTOMER_ID).fullName("Cust").role(UserRole.CUSTOMER).build();
        com.aiwa.entity.Service svc = com.aiwa.entity.Service.builder()
                .id(3L).name("Haircut").durationMinutes(30).price(new BigDecimal("100")).provider(provider).build();
        return Booking.builder().id(55L).customer(customer).provider(provider).service(svc)
                .status(status).totalPrice(new BigDecimal("100"))
                .bookingDate(start.toLocalDate()).startTime(start.toLocalTime())
                .endTime(start.toLocalTime().plusMinutes(30)).build();
    }

    /** The next clock change of the business zone after {@code from}: forward (a gap) or back (an overlap). */
    private static ZoneOffsetTransition clockChange(boolean forward) {
        Instant from = Instant.parse("2026-01-01T00:00:00Z");
        for (int i = 0; i < 4; i++) {
            ZoneOffsetTransition t = AiwaTime.ZONE.getRules().nextTransition(from);
            if (t == null) break;
            if (t.isGap() == forward) return t;
            from = t.getInstant();
        }
        assumeTrue(false, "the business zone has no daylight-saving change");
        return null;
    }

    private static LocalDateTime wall(Instant instant) {
        return LocalDateTime.ofInstant(instant, AiwaTime.ZONE);
    }

    /**
     * Runs {@code action} with the clock at {@code instant}: the instant itself and
     * the wall clock of the business zone, which is also the JVM's zone in the
     * running application (AiwaApplication sets it at start-up).
     */
    private static <T> T at(Instant instant, Supplier<T> action) {
        LocalDateTime wall = wall(instant);
        TimeZone jvmZone = TimeZone.getDefault();
        TimeZone.setDefault(TimeZone.getTimeZone(AiwaTime.ZONE));
        try (MockedStatic<LocalDateTime> local = mockStatic(LocalDateTime.class, CALLS_REAL_METHODS);
             MockedStatic<Instant> clock = mockStatic(Instant.class, CALLS_REAL_METHODS)) {
            local.when(LocalDateTime::now).thenReturn(wall);
            local.when(() -> LocalDateTime.now(any(ZoneId.class))).thenReturn(wall);
            clock.when(Instant::now).thenReturn(instant);
            return action.get();
        } finally {
            TimeZone.setDefault(jvmZone);
        }
    }

    private int sweep(Booking pending, Instant now, long windowMinutes) {
        when(platformSettings.getResponseWindowMinutes(any())).thenReturn(windowMinutes);
        when(bookingRepo.findByStatus(BookingStatus.PENDING)).thenReturn(List.of(pending));
        return at(now, service::expireStalePendingBookings);
    }

    // ── response window ───────────────────────────────────────────────────────

    @Test
    void aRequestIsNotExpiredAnHourEarlyOnTheNightTheClocksGoForward() {
        ZoneOffsetTransition change = clockChange(true);
        Instant created = change.getInstant().minus(Duration.ofMinutes(10));       // 23:50
        Booking b = booking(BookingStatus.PENDING, wall(created).plusDays(2));
        b.setCreatedAt(wall(created));

        // 20 minutes later the wall clock says 01:10: 80 minutes "passed" on paper.
        assertThat(sweep(b, created.plus(Duration.ofMinutes(20)), 30)).isZero();
        assertThat(b.getStatus()).isEqualTo(BookingStatus.PENDING);

        // 35 real minutes later the 30-minute window is over.
        assertThat(sweep(b, created.plus(Duration.ofMinutes(35)), 30)).isEqualTo(1);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.EXPIRED);
    }

    @Test
    void aRequestIsNotKeptAnExtraHourOnTheNightTheClocksGoBack() {
        ZoneOffsetTransition change = clockChange(false);
        Instant created = change.getInstant().minus(Duration.ofMinutes(10));       // 23:50, first time round
        Booking b = booking(BookingStatus.PENDING, wall(created).plusDays(2));
        b.setCreatedAt(wall(created));

        // 20 minutes later the wall clock says 23:10 again: the request looked 40 minutes "younger".
        assertThat(sweep(b, created.plus(Duration.ofMinutes(20)), 15)).isEqualTo(1);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.EXPIRED);
    }

    // ── cancellation cut-off ──────────────────────────────────────────────────

    @Test
    void theCancellationCutoffIsRealHoursOnTheNightTheClocksGoForward() {
        ZoneOffsetTransition change = clockChange(true);
        LocalDateTime appointment = change.getDateTimeAfter().plusHours(1);        // 02:00, right after the change
        Instant startsAt = appointment.atZone(AiwaTime.ZONE).toInstant();
        when(platformSettings.getCancellationCutoffHours(any())).thenReturn(2);
        Booking b = booking(BookingStatus.ACCEPTED, appointment);
        when(bookingRepo.findById(55L)).thenReturn(Optional.of(b));

        // 90 minutes before the start, wall clock 23:30: "02:00 minus 2 hours" read 00:00, so this passed.
        assertThatThrownBy(() -> at(startsAt.minus(Duration.ofMinutes(90)),
                () -> service.updateStatus(CUSTOMER_ID, 55L, BookingStatus.CANCELLED)))
                .isInstanceOf(BusinessException.class).hasMessageContaining("Cancellation deadline passed");
        assertThat(b.getStatus()).isEqualTo(BookingStatus.ACCEPTED);

        // 150 minutes before the start is still in time.
        at(startsAt.minus(Duration.ofMinutes(150)),
                () -> service.updateStatus(CUSTOMER_ID, 55L, BookingStatus.CANCELLED));
        assertThat(b.getStatus()).isEqualTo(BookingStatus.CANCELLED);
    }
}
