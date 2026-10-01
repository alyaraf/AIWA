package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/** Deletes revoked-token records once those tokens have expired anyway (DR-002). */
@Slf4j
@Component
@Profile("!test")
@RequiredArgsConstructor
public class RevokedTokenPurgeScheduler {

    private final TokenBlacklistService blacklist;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelay = 6 * 60 * 60 * 1000L, initialDelay = 10 * 60 * 1000L)   // every 6 h
    public void purge() {
        // Idempotent, so it may run without the lock while Redis is down.
        redisLockService.withLock("revoked-token-purge", Duration.ofMinutes(10), true, () -> {
            int removed = blacklist.purgeExpired();
            if (removed > 0) log.info("Removed {} expired revoked-token record(s)", removed);
        });
    }
}
