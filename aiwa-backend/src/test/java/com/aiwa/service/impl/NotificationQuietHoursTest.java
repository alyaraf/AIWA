package com.aiwa.service.impl;

import com.aiwa.entity.User;
import org.junit.jupiter.api.Test;

import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;

/** Quiet-hours window logic used to gate real-time push delivery. */
class NotificationQuietHoursTest {

    private User withQuietHours(LocalTime start, LocalTime end) {
        return User.builder().quietHoursStart(start).quietHoursEnd(end).build();
    }

    @Test
    void noWindowMeansNeverQuiet() {
        assertThat(NotificationServiceImpl.withinQuietHours(withQuietHours(null, null), LocalTime.of(3, 0)))
                .isFalse();
    }

    @Test
    void sameDayWindow() {
        User u = withQuietHours(LocalTime.of(9, 0), LocalTime.of(17, 0));
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(12, 0))).isTrue();
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(8, 59))).isFalse();
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(17, 0))).isFalse(); // end exclusive
    }

    @Test
    void overnightWindowWrapsMidnight() {
        User u = withQuietHours(LocalTime.of(22, 0), LocalTime.of(7, 0));
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(23, 30))).isTrue();
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(3, 0))).isTrue();
        assertThat(NotificationServiceImpl.withinQuietHours(u, LocalTime.of(12, 0))).isFalse();
    }
}
