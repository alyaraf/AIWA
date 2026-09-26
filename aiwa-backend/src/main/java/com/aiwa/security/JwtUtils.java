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

    private Key getSigningKey() {
        return Keys.hmacShaKeyFor(jwtSecret.getBytes());
    }

    public String generateAccessToken(String identifier, Long userId, String role) {
        return Jwts.builder()
                .setSubject(identifier)
                .claim("userId", userId)
                .claim("role", role)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + jwtExpiration))
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    public String generateRefreshToken(String identifier) {
        return Jwts.builder()
                .setSubject(identifier)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + refreshExpiration))
                .signWith(getSigningKey(), SignatureAlgorithm.HS256)
                .compact();
    }

    private static final long MFA_CHALLENGE_TTL_MILLIS = 5 * 60 * 1000; // 5 minutes
    private static final String MFA_PURPOSE_CLAIM = "purpose";
    private static final String MFA_PURPOSE_VALUE = "mfa_challenge";

    /**
     * A short-lived, single-purpose token issued after a password check when
     * the account has 2FA enabled. It carries no role/authority claims and is
     * only ever accepted by {@code POST /auth/2fa/verify} — it cannot be used
     * as a normal access token even if it leaked, because JwtAuthFilter only
     * looks for "role"/"userId", and the 2FA endpoint explicitly requires the
     * "purpose" claim below.
     */
    public String generateMfaChallengeToken(String identifier) {
        return Jwts.builder()
                .setSubject(identifier)
                .claim(MFA_PURPOSE_CLAIM, MFA_PURPOSE_VALUE)
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + MFA_CHALLENGE_TTL_MILLIS))
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
