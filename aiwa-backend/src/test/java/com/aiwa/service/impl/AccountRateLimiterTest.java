package com.aiwa.service.impl;

import com.aiwa.exception.TooManyRequestsException;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** S-07: with Redis down the per-account budget is still enforced (in-process) and the outage is counted. */
class AccountRateLimiterTest {

    @Test
    void enforcesTheBudgetInProcessAndCountsTheOutageWhileRedisIsDown() {
        RedisRuntimeService redis = mock(RedisRuntimeService.class);
        when(redis.increment(anyString(), any(Duration.class))).thenThrow(new RuntimeException("Connection refused"));
        SimpleMeterRegistry meters = new SimpleMeterRegistry();
        AccountRateLimiter limiter = new AccountRateLimiter(redis);
        limiter.setMeterRegistry(meters);

        assertThatCode(() -> {
            limiter.check(7L, "chat", 2, Duration.ofMinutes(1));
            limiter.check(7L, "chat", 2, Duration.ofMinutes(1));
        }).doesNotThrowAnyException();
        assertThatThrownBy(() -> limiter.check(7L, "chat", 2, Duration.ofMinutes(1)))
                .isInstanceOf(TooManyRequestsException.class);
        // Another account has its own budget.
        assertThatCode(() -> limiter.check(8L, "chat", 2, Duration.ofMinutes(1))).doesNotThrowAnyException();

        assertThat(meters.counter("aiwa.ratelimit.redis.unavailable", "scope", "account").count()).isEqualTo(4.0);
    }
}
