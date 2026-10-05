package com.aiwa.security;

import com.aiwa.service.impl.RedisRuntimeService;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** A Redis outage must not block logins, nor switch the limits off (in-process fallback, S-07). */
class RedisRateLimitFilterTest {

    private final RedisRuntimeService redis = mock(RedisRuntimeService.class);
    private final RedisRateLimitFilter filter = new RedisRateLimitFilter(redis);

    @Test
    void allowsLoginThroughWhenRedisIsUnreachable() throws Exception {
        when(redis.increment(anyString(), any(Duration.class))).thenThrow(new RuntimeException("Connection refused"));
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilterInternal(request, response, chain);

        verify(chain).doFilter(request, response); // request proceeded, not a 500 dead-end
        assertThat(response.getStatus()).isEqualTo(200); // MockHttpServletResponse default = 200 (untouched)
    }

    @Test
    void stillEnforcesTheLimitWhenRedisIsHealthy() throws Exception {
        when(redis.increment(anyString(), any(Duration.class))).thenReturn(11L); // over the max of 10
        MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilterInternal(request, response, chain);

        verify(chain, never()).doFilter(any(), any());
        assertThat(response.getStatus()).isEqualTo(429);

    }

    @Test
    void stillLimitsLoginsInProcessAndCountsTheOutageWhileRedisIsDown() throws Exception {
        when(redis.increment(anyString(), any(Duration.class))).thenThrow(new RuntimeException("Connection refused"));
        io.micrometer.core.instrument.simple.SimpleMeterRegistry meters = new io.micrometer.core.instrument.simple.SimpleMeterRegistry();
        filter.setMeterRegistry(meters);

        int blocked = 0;
        for (int i = 0; i < 12; i++) { // the login limit is 10 a minute per IP
            MockHttpServletRequest request = new MockHttpServletRequest("POST", "/api/auth/login");
            request.setRemoteAddr("203.0.113.9");
            MockHttpServletResponse response = new MockHttpServletResponse();
            filter.doFilterInternal(request, response, mock(FilterChain.class));
            if (response.getStatus() == 429) blocked++;
        }

        assertThat(blocked).isEqualTo(2); // requests 11 and 12: the limit is not switched off
        assertThat(meters.counter("aiwa.ratelimit.redis.unavailable", "scope", "ip").count()).isEqualTo(12.0);
    }
}
