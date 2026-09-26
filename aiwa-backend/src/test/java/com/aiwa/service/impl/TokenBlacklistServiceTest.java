package com.aiwa.service.impl;

import com.aiwa.security.JwtUtils;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.*;

/**
 * A Redis outage/hiccup must never make every already-logged-in user look
 * unauthorized. The blacklist is a best-effort revocation layer on top of the
 * JWT's own signature + expiry check — it fails OPEN, not closed.
 */
class TokenBlacklistServiceTest {

    private final RedisRuntimeService redis = mock(RedisRuntimeService.class);
    private final JwtUtils jwtUtils = mock(JwtUtils.class);
    private final TokenBlacklistService service = new TokenBlacklistService(redis, jwtUtils);

    @Test
    void reportsBlacklistedWhenRedisConfirmsIt() {
        when(redis.exists("jwt:blacklist:" + Integer.toHexString("t".hashCode()))).thenReturn(true);
        assertThat(service.isBlacklisted("t")).isTrue();
    }

    @Test
    void treatsTokenAsNotBlacklistedWhenRedisIsUnreachable() {
        when(redis.exists(anyString())).thenThrow(new RuntimeException("Connection refused"));
        assertThat(service.isBlacklisted("some-token")).isFalse();
    }

    @Test
    void nullTokenIsNeverBlacklistedAndNeverTouchesRedis() {
        assertThat(service.isBlacklisted(null)).isFalse();
        verifyNoInteractions(redis);
    }

    @Test
    void blacklistingDoesNotThrowWhenRedisIsUnreachable() {
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.getRemainingValidityMillis("t")).thenReturn(60000L);
        doThrow(new RuntimeException("down")).when(redis).set(anyString(), anyString(), any());

        // Logout must still report success even if Redis can't record the revocation.
        assertThatCode(() -> service.blacklist("t")).doesNotThrowAnyException();
    }
}
