package com.aiwa.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.security.Key;
import java.util.Date;

@Slf4j
@Component
public class JwtUtils {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.expiration}")
    private long jwtExpiration;

    @Value("${jwt.refresh-expiration}")
    private long refreshExpiration;

    /** L-18: admin sessions are kept in the browser, so their refresh token lives hours, not days. */
    @Value("${jwt.admin-refresh-expiration:28800000}")
    private long adminRefreshExpiration = 28_800_000L;

    private Key getSigningKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    /**
     * Every token carries a "typ" claim so one kind can never be replayed as
     * another: before this, JwtAuthFilter accepted any correctly-signed token,
     * so a 7-day refresh token worked as an access token and — worse — the
     * 5-minute MFA challenge token (issued after the password step alone)
     * authenticated API calls, skipping the TOTP step entirely.
     */
    static final String TYPE_CLAIM = "typ";
    static final String TYPE_ACCESS = "access";
    static final String TYPE_REFRESH = "refresh";
    static final String TYPE_MFA = "mfa";

    /**
     * Issue time in milliseconds (DR-018). The standard iat claim has second
     * precision, so a token issued in the same second as a password reset or
     * suspension, but before it, used to pass the session cut-off.
     */
    static final String ISSUED_AT_MILLIS_CLAIM = "iatms";

    public String generateAccessToken(String identifier, Long userId, String role) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .setSubject(identifier)
                .claim(TYPE_CLAIM, TYPE_ACCESS)
                .claim("userId", userId)
                .claim("role", role)
                .claim(ISSUED_AT_MILLIS_CLAIM, now)
                .setId(java.util.UUID.randomUUID().toString())
                .setIssuedAt(new Date(now))
                .setExpiration(new Date(now + jwtExpiration))
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    public String generateRefreshToken(String identifier) {
        return generateRefreshToken(identifier, null);
    }

    /** The userId claim lets a refresh resolve the account by id, never by guessing from the subject (V-01). */
    public String generateRefreshToken(String identifier, Long userId) {
        return generateRefreshToken(identifier, userId, false);
    }

    /** @param admin an admin account: the shorter admin lifetime applies (L-18) */
    public String generateRefreshToken(String identifier, Long userId, boolean admin) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .setSubject(identifier)
                .claim(TYPE_CLAIM, TYPE_REFRESH)
                .claim("userId", userId)
                .claim(ISSUED_AT_MILLIS_CLAIM, now)
                // Unique id so two refreshes in the same second never produce the
                // same string (rotation blacklists the old one).
                .setId(java.util.UUID.randomUUID().toString())
                .setIssuedAt(new Date(now))
                .setExpiration(new Date(now + (admin ? adminRefreshExpiration : refreshExpiration)))
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    /**
     * True only for a valid access token. Tokens minted before the "typ" claim
     * existed are still accepted for their remaining lifetime when they carry
     * the access-only "role" claim (refresh and MFA tokens never had one).
     */
    public boolean isAccessToken(String token) {
        try {
            Claims c = parseClaims(token);
            String typ = c.get(TYPE_CLAIM, String.class);
            if (typ != null) return TYPE_ACCESS.equals(typ);
            return c.get("role") != null && c.get(MFA_PURPOSE_CLAIM) == null;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    /** True only for a valid refresh token (legacy: no typ, no role, no MFA purpose). */
    public boolean isRefreshToken(String token) {
        try {
            Claims c = parseClaims(token);
            String typ = c.get(TYPE_CLAIM, String.class);
            if (typ != null) return TYPE_REFRESH.equals(typ);
            return c.get("role") == null && c.get(MFA_PURPOSE_CLAIM) == null;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    /**
     * Issue time in milliseconds when the token carries it, else the second-precision
     * iat (older tokens: treated as issued at the start of that second, so a cut-off
     * within the same second rejects them). Null when absent.
     */
    public java.time.Instant getIssuedAt(String token) {
        Claims c = parseClaims(token);
        Number ms = c.get(ISSUED_AT_MILLIS_CLAIM, Number.class);
        if (ms != null) return java.time.Instant.ofEpochMilli(ms.longValue());
        Date iat = c.getIssuedAt();
        return iat == null ? null : iat.toInstant();
    }

    private static final long MFA_CHALLENGE_TTL_MILLIS = 5 * 60 * 1000; // 5 minutes
    private static final String MFA_PURPOSE_CLAIM = "purpose";
    private static final String MFA_PURPOSE_VALUE = "mfa_challenge";

    /**
     * A short-lived, single-purpose token issued after a password check when
     * the account has 2FA enabled. It carries no role/authority claims and is
     * only ever accepted by {@code POST /auth/2fa/verify} — JwtAuthFilter only
     * authenticates tokens for which {@link #isAccessToken} is true, and the 2FA
     * endpoint explicitly requires the "purpose" claim below.
     */
    public String generateMfaChallengeToken(String identifier) {
        return generateMfaChallengeToken(identifier, null);
    }

    public String generateMfaChallengeToken(String identifier, Long userId) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .setSubject(identifier)
                .claim(TYPE_CLAIM, TYPE_MFA)
                .claim(MFA_PURPOSE_CLAIM, MFA_PURPOSE_VALUE)
                .claim("userId", userId)
                .claim(ISSUED_AT_MILLIS_CLAIM, now)
                .setId(java.util.UUID.randomUUID().toString())
                .setIssuedAt(new Date(now))
                .setExpiration(new Date(now + MFA_CHALLENGE_TTL_MILLIS))
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    public boolean isMfaChallengeToken(String token) {
        try {
            return MFA_PURPOSE_VALUE.equals(parseClaims(token).get(MFA_PURPOSE_CLAIM, String.class));
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public String getSubjectFromToken(String token) {
        return parseClaims(token).getSubject();
    }

    public Long getUserIdFromToken(String token) {
        return parseClaims(token).get("userId", Long.class);
    }

    public boolean validateToken(String token) {
        try {
            parseClaims(token);
            return true;
        } catch (ExpiredJwtException e) {
            log.warn("JWT expired: {}", e.getMessage());
        } catch (JwtException | IllegalArgumentException e) {
            log.warn("Invalid JWT: {}", e.getMessage());
        }
        return false;
    }

    public long getRemainingValidityMillis(String token) {
        Date expiration = parseClaims(token).getExpiration();
        return expiration.getTime() - System.currentTimeMillis();
    }

    private Claims parseClaims(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
    }
}
