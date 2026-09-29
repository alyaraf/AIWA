package com.aiwa.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

/** Each token kind is recognised only as itself (the 2FA-bypass / refresh-as-access fix). */
class JwtUtilsTokenTypeTest {

    private final JwtUtils jwt = new JwtUtils();

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(jwt, "jwtSecret", "test-secret-test-secret-test-secret-test-secret-0123");
        ReflectionTestUtils.setField(jwt, "jwtExpiration", 60_000L);
        ReflectionTestUtils.setField(jwt, "refreshExpiration", 120_000L);
    }

    @Test
    void accessTokenIsOnlyAnAccessToken() {
        String t = jwt.generateAccessToken("a@x.com", 1L, "CUSTOMER");
        assertThat(jwt.isAccessToken(t)).isTrue();
        assertThat(jwt.isRefreshToken(t)).isFalse();
        assertThat(jwt.isMfaChallengeToken(t)).isFalse();
        assertThat(jwt.getIssuedAt(t)).isNotNull();
    }

    @Test
    void refreshTokenIsOnlyARefreshToken() {
        String t = jwt.generateRefreshToken("a@x.com");
        assertThat(jwt.isRefreshToken(t)).isTrue();
        assertThat(jwt.isAccessToken(t)).isFalse();
    }

    @Test
    void mfaChallengeTokenIsNeitherAccessNorRefresh() {
        String t = jwt.generateMfaChallengeToken("admin@x.com");
        assertThat(jwt.isMfaChallengeToken(t)).isTrue();
        assertThat(jwt.isAccessToken(t)).isFalse();
        assertThat(jwt.isRefreshToken(t)).isFalse();
    }

    @Test
    void twoRefreshTokensInTheSameSecondDiffer() {
        // Rotation blacklists the old token; identical strings would revoke the new one too.
        assertThat(jwt.generateRefreshToken("a@x.com")).isNotEqualTo(jwt.generateRefreshToken("a@x.com"));
    }

    @Test
    void garbageIsNoKindOfToken() {
        assertThat(jwt.isAccessToken("not.a.jwt")).isFalse();
        assertThat(jwt.isRefreshToken("not.a.jwt")).isFalse();
    }
}
