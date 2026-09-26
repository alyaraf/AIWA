package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * Auto-expires PENDING booking requests the provider never answered within the
 * configured response window (aiwa.booking.response-window-minutes). Runs every
 * 5 minutes and is guarded by a Redis lock so only one instance acts at a time.
 */
@Slf4j
@Component
@Profile("!test")
@RequiredArgsConstructor
public class BookingExpiryScheduler {

    private final BookingServiceImpl bookingService;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelay = 5 * 60 * 1000)   // every 5 min
    public void expireStaleRequests() {
        redisLockService.withLock("booking-expiry", Duration.ofMinutes(5), () -> {
            int expired = bookingService.expireStalePendingBookings();
            if (expired > 0) {
                log.info("Expired {} stale PENDING booking request(s)", expired);
            }
        });
    }
}
