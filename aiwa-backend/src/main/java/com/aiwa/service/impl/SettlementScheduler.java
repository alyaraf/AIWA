package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;

/** Hourly settlement sweep (overdue marking + booking pause), one instance at a time. */
@Component
@Profile("!test")
@RequiredArgsConstructor
public class SettlementScheduler {

    private final SettlementService settlementService;
    private final RedisLockService redisLockService;

    @Scheduled(fixedDelay = 60 * 60 * 1000, initialDelay = 2 * 60 * 1000)
    public void sweep() {
        redisLockService.withLock("settlement-sweep", Duration.ofMinutes(30), settlementService::sweep);
    }
}
