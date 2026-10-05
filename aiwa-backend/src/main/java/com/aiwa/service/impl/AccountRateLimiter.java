package com.aiwa.service.impl;

import com.aiwa.exception.TooManyRequestsException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;

/**
 * Per-account budgets for actions that cost money or bury support (DR-028):
 * chat, reports, complaints and uploads. The IP limit in RedisRateLimitFilter
 * only covers the sign-in routes. When Redis is down the budget is counted in this process
 * instead (S-07); nothing here protects safety, it only stops abuse.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AccountRateLimiter {

    private final RedisRuntimeService redis;
    private final com.aiwa.util.LocalWindowCounter localFallback = new com.aiwa.util.LocalWindowCounter();
    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMeterRegistry(io.micrometer.core.instrument.MeterRegistry registry) {
        this.meterRegistry = registry;
    }

    public void check(Long userId, String action, int max, Duration window) {
        if (userId == null) return;
        String key = "rl:acct:" + action + ":" + userId;
        long count;
        try {
            count = redis.increment(key, window);
        } catch (RuntimeException e) {
            // S-07: count in this process instead of switching the limit off, and make the outage visible.
            count = localFallback.increment(key, window);
            if (meterRegistry != null) {
                meterRegistry.counter("aiwa.ratelimit.redis.unavailable", "scope", "account").increment();
            }
            log.error("RATE_LIMIT_REDIS_UNAVAILABLE scope=account action={} - enforcing the limit in-process: {}", action, e.getMessage());
        }
        if (count > max) {
            throw new TooManyRequestsException("error.too_many_requests");
        }
    }
}
