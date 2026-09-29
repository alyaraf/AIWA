package com.aiwa;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

import java.util.TimeZone;

@SpringBootApplication
@EnableJpaAuditing
@EnableScheduling
public class AiwaApplication {
    public static void main(String[] args) {
        // Booking slots, reminders, expiry and "open now" are Cairo wall-clock
        // times. A container defaults to UTC, which would shift every
        // LocalDate.now()/LocalTime.now() by 2–3 hours.
        TimeZone.setDefault(TimeZone.getTimeZone(com.aiwa.util.AiwaTime.ZONE));
        SpringApplication.run(AiwaApplication.class, args);
    }
}
