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

/** A Redis outage must not block logins — the rate limiter fails open. */
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
}
