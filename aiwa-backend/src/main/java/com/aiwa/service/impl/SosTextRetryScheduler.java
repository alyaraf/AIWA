package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * CR-08: re-sends SOS texts that were not delivered (lost in a restart, or
 * FAILED and past their back-off) until the SOS is closed. One instance at a
 * time; during a Redis outage it still runs, because a second text is better
 * than none.
 */
@Component
@Profile("!test")
@RequiredArgsConstructor
public class SosTextRetryScheduler {

    private final SafetyService safetyService;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelayString = "${aiwa.safety.sos-retry.sweep-interval-ms:30000}",
            initialDelayString = "${aiwa.safety.sos-retry.sweep-interval-ms:30000}")
    public void sweep() {
        redisLockService.withLock("sos-text-retry", Duration.ofMinutes(1), true, safetyService::retryDueSosTexts);
    }
}
