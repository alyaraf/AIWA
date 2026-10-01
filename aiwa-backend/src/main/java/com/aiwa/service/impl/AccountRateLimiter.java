package com.aiwa.service.impl;

import com.aiwa.exception.TooManyRequestsException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;

/**
 * Per-account budgets for actions that cost money or bury support (DR-028):
 * chat, reports, complaints and uploads. The IP limit in RedisRateLimitFilter
 * only covers the sign-in routes. Fails open when Redis is down; nothing here
 * protects safety, it only stops abuse.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AccountRateLimiter {

    private final RedisRuntimeService redis;

    public void check(Long userId, String action, int max, Duration window) {
        if (userId == null) return;
        long count;
        try {
            count = redis.increment("rl:acct:" + action + ":" + userId, window);
        } catch (RuntimeException e) {
            log.warn("Account rate limit unavailable for {} (Redis down?): {}", action, e.getMessage());
            return;
        }
        if (count > max) {
            throw new TooManyRequestsException("error.too_many_requests");
        }
    }
}
