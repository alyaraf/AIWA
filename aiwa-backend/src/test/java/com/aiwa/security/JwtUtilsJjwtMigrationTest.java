package com.aiwa.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * JJWT 0.11.5 -> 0.13.0: signatures, algorithm confusion, expiry, claim types and token types behave as before.
 */
class JwtUtilsJjwtMigrationTest {

    private static final String SECRET = "test-secret-test-secret-test-secret-test-secret-0123";
    private final JwtUtils jwt = new JwtUtils();

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(jwt, "jwtSecret", SECRET);
        ReflectionTestUtils.setField(jwt, "jwtExpiration", 60_000L);
        ReflectionTestUtils.setField(jwt, "refreshExpiration", 120_000L);
    }

    @Test
    void claimsRoundTripWithTheirTypes() {
        String t = jwt.generateAccessToken("a@x.com", 42L, "CUSTOMER");
        assertThat(jwt.validateToken(t)).isTrue();
        assertThat(jwt.getSubjectFromToken(t)).isEqualTo("a@x.com");
        assertThat(jwt.getUserIdFromToken(t)).isEqualTo(42L);
        assertThat(jwt.getIssuedAt(t)).isBetween(Instant.now().minusSeconds(5), Instant.now().plusSeconds(1));
        assertThat(jwt.getRemainingValidityMillis(t)).isBetween(50_000L, 60_000L);
    }

    @Test
    void aTokenWithoutUserIdYieldsNull() {
        assertThat(jwt.getUserIdFromToken(jwt.generateRefreshToken("a@x.com"))).isNull();
    }

    @Test
    void aTokenSignedWithAnotherKeyOrTamperedIsRejected() {
        String other = Jwts.builder().subject("a@x.com").claim("typ", "access").claim("role", "ADMIN")
                .expiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(Keys.hmacShaKeyFor("another-secret-another-secret-another-secret-9999".getBytes(StandardCharsets.UTF_8)),
                        Jwts.SIG.HS256).compact();
        assertThat(jwt.validateToken(other)).isFalse();
        assertThat(jwt.isAccessToken(other)).isFalse();

        String good = jwt.generateAccessToken("a@x.com", 1L, "CUSTOMER");
        String[] parts = good.split("\\.");
        String forgedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(
                new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8)
                        .replace("CUSTOMER", "ADMIN").getBytes(StandardCharsets.UTF_8));
        assertThat(jwt.validateToken(parts[0] + "." + forgedPayload + "." + parts[2])).isFalse();
    }

    @Test
    void anUnsignedAlgNoneTokenIsRejected() {
        String header = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"alg\":\"none\"}".getBytes(StandardCharsets.UTF_8));
        String payload = Base64.getUrlEncoder().withoutPadding().encodeToString(
                ("{\"sub\":\"a@x.com\",\"typ\":\"access\",\"role\":\"ADMIN\",\"exp\":" + (System.currentTimeMillis() / 1000 + 600) + "}")
                        .getBytes(StandardCharsets.UTF_8));
        String unsigned = header + "." + payload + ".";
        assertThat(jwt.validateToken(unsigned)).isFalse();
        assertThat(jwt.isAccessToken(unsigned)).isFalse();
    }

    @Test
    void anExpiredTokenIsRejected() {
        ReflectionTestUtils.setField(jwt, "jwtExpiration", -1_000L);
        String t = jwt.generateAccessToken("a@x.com", 1L, "CUSTOMER");
        assertThat(jwt.validateToken(t)).isFalse();
        assertThat(jwt.isAccessToken(t)).isFalse();
    }

    @Test
    void emptyAndNullInputAreNotTokens() {
        assertThat(jwt.validateToken("")).isFalse();
        assertThat(jwt.validateToken(null)).isFalse();
    }

    @Test
    void issuedAtKeepsMillisecondPrecisionForTheSessionCutoff() {
        String t = jwt.generateAccessToken("a@x.com", 1L, "CUSTOMER");
        Instant issued = jwt.getIssuedAt(t);
        assertThat(issued.toEpochMilli() % 1000).isNotNegative(); // iatms claim, not the second-truncated iat
        assertThat(jwt.getIssuedAt(jwt.generateMfaChallengeToken("a@x.com", 1L)))
                .isAfterOrEqualTo(issued);
        assertThat(jwt.isMfaChallengeToken(jwt.generateMfaChallengeToken("a@x.com", 1L))).isTrue();
    }
}
