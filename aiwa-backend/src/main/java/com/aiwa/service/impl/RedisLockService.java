package com.aiwa.service.impl;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.UUID;

/**
 * One-instance-at-a-time guard for scheduled jobs (DR-025).
 *
 * <p>The lock is released with an atomic compare-and-delete, so an instance
 * whose lock already expired can no longer delete the lock another instance
 * now holds. When Redis is unreachable, a job runs only if it said it is safe
 * to run twice; the settlement sweep (money) is skipped instead.</p>
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class RedisLockService {

    private final RedisRuntimeService redis;

    /** Skips the work when Redis is unreachable (the safe default for anything touching money). */
    public boolean withLock(String lockName, Duration ttl, Runnable work) {
        return withLock(lockName, ttl, false, work);
    }

    /**
     * @param runIfRedisDown true only for idempotent jobs, which then still run
     *                       on a single instance during a Redis outage
     * @return whether the work ran
     */
    public boolean withLock(String lockName, Duration ttl, boolean runIfRedisDown, Runnable work) {
        String key = "lock:" + lockName;
        String owner = UUID.randomUUID().toString();
        try {
            if (!redis.setIfAbsent(key, owner, ttl)) {
                return false;
            }
        } catch (RuntimeException ex) {
            if (!runIfRedisDown) {
                log.warn("Redis lock unavailable for {} — skipping this run: {}", lockName, ex.getMessage());
                return false;
            }
            log.warn("Redis lock unavailable for {} — running without it (idempotent job): {}", lockName, ex.getMessage());
            work.run();
            return true;
        }
        try {
            work.run();
            return true;
        } finally {
            try {
                redis.compareAndDelete(key, owner);
            } catch (RuntimeException ex) {
                log.warn("Redis lock release failed for {} (it expires on its own): {}", lockName, ex.getMessage());
            }
        }
    }
}
