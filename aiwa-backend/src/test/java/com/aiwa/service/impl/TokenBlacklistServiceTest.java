package com.aiwa.service.impl;

import com.aiwa.entity.RevokedToken;
import com.aiwa.repository.RevokedTokenRepository;
import com.aiwa.security.JwtUtils;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * DR-002: the database is the record of revoked and spent tokens; Redis is a
 * fast check in front of it. A Redis outage must neither sign everyone out nor
 * let a logged-out or spent token back in.
 */
class TokenBlacklistServiceTest {

    private final RedisRuntimeService redis = mock(RedisRuntimeService.class);
    private final JwtUtils jwtUtils = mock(JwtUtils.class);
    private final RevokedTokenRepository repo = mock(RevokedTokenRepository.class);
    private final TokenBlacklistService service = new TokenBlacklistService(redis, jwtUtils, repo);

    @Test
    void reportsBlacklistedWhenRedisConfirmsIt() {
        when(redis.exists("jwt:blacklist:" + Integer.toHexString("t".hashCode()))).thenReturn(true);
        assertThat(service.isBlacklisted("t")).isTrue();
    }

    @Test
    void withRedisDownALoggedOutTokenIsStillRefusedFromTheDatabase() {
        when(redis.exists(anyString())).thenThrow(new RuntimeException("Connection refused"));
        when(repo.existsById(TokenBlacklistService.hash("logged-out"))).thenReturn(true);

        assertThat(service.isBlacklisted("logged-out")).isTrue();
        // ...and a valid token is not treated as revoked.
        assertThat(service.isBlacklisted("still-good")).isFalse();
    }

    @Test
    void nullTokenIsNeverBlacklistedAndNeverTouchesRedis() {
        assertThat(service.isBlacklisted(null)).isFalse();
        verifyNoInteractions(redis);
    }

    @Test
    void logoutRecordsTheTokenInTheDatabaseEvenWhenRedisIsDown() {
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.getRemainingValidityMillis("t")).thenReturn(60000L);
        doThrow(new RuntimeException("down")).when(redis).set(anyString(), anyString(), any());

        assertThatCode(() -> service.revoke("t")).doesNotThrowAnyException();
        verify(repo).saveAndFlush(argThat(r -> r.getTokenHash().equals(TokenBlacklistService.hash("t"))));
    }

    @Test
    void aLogoutDuringARedisOutageStillHoldsAfterRedisComesBack() {
        // AU-14 / L-7: Redis came back without the entry; the database copy must still count.
        when(jwtUtils.validateToken("t")).thenReturn(true);
        when(jwtUtils.getRemainingValidityMillis("t")).thenReturn(60000L);
        doThrow(new RuntimeException("down")).when(redis).set(anyString(), anyString(), any());
        service.revoke("t");

        when(redis.exists(anyString())).thenReturn(false); // Redis is back, entry missing
        when(repo.existsById(TokenBlacklistService.hash("t"))).thenReturn(true);
        assertThat(service.isBlacklisted("t")).isTrue();
        assertThat(service.isBlacklisted("other")).isFalse();
    }

    // SEC-01: a Redis miss proves nothing, so the database settles it on every request.
    @Test
    void aRedisMissIsAlwaysSettledByTheDatabase() {
        when(redis.exists(anyString())).thenReturn(false);
        when(repo.existsById(TokenBlacklistService.hash("revoked-after-cache-loss"))).thenReturn(true);

        assertThat(service.isBlacklisted("revoked-after-cache-loss")).isTrue();
        assertThat(service.isBlacklisted("fine")).isFalse();
        verify(repo, never()).findById(anyString()); // no gap-marker bookkeeping any more
    }

    @Test
    void aDatabaseFailureOnAMissPropagatesInsteadOfGuessingTheTokenIsFine() {
        when(redis.exists(anyString())).thenReturn(false);
        when(repo.existsById(anyString())).thenThrow(new org.springframework.dao.DataAccessResourceFailureException("db down"));
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> service.isBlacklisted("t"))
                .isInstanceOf(org.springframework.dao.DataAccessResourceFailureException.class);
    }

    @Test
    void aRefreshTokenCanBeSpentOnlyOnceEvenWithRedisDown() {
        when(jwtUtils.getRemainingValidityMillis("r")).thenReturn(60000L);
        when(redis.exists(anyString())).thenThrow(new RuntimeException("down"));
        when(repo.saveAndFlush(any(RevokedToken.class)))
                .thenAnswer(inv -> inv.getArgument(0))
                .thenThrow(new DataIntegrityViolationException("duplicate key"));

        assertThat(service.claimStrict("r")).isTrue();
        assertThat(service.claimStrict("r")).isFalse();
    }

    // AQ-06: the spent token's Redis copy had no reader and kept every refresh token in Redis for up to 7 days.
    @Test
    void spendingATokenWritesOnlyTheDatabase() {
        when(jwtUtils.getRemainingValidityMillis("r")).thenReturn(60000L);
        when(repo.saveAndFlush(any(RevokedToken.class))).thenAnswer(inv -> inv.getArgument(0));

        assertThat(service.claimStrict("r")).isTrue();
        verify(redis, never()).set(anyString(), anyString(), any());
    }
}
