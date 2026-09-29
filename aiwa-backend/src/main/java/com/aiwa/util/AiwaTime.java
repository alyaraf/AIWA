package com.aiwa.util;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * Business time zone. Bookings, working hours and "today" are all Cairo local
 * time; containers usually run in UTC, so anything comparing against a booking
 * slot or a provider's hours must go through here (AiwaApplication also sets
 * the JVM default to this zone at startup).
 */
public final class AiwaTime {

    public static final ZoneId ZONE = ZoneId.of(
            System.getenv().getOrDefault("AIWA_TIMEZONE", "Africa/Cairo"));

    private AiwaTime() {}

    public static LocalDate today() {
        return LocalDate.now(ZONE);
    }

    public static LocalTime timeNow() {
        return LocalTime.now(ZONE);
    }

    public static LocalDateTime now() {
        return LocalDateTime.now(ZONE);
    }
}
