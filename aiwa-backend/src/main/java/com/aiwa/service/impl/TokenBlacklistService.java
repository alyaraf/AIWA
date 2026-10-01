package com.aiwa.service.impl;

import com.aiwa.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Slf4j
@Service
@RequiredArgsConstructor
public class TokenBlacklistService {

    private final RedisRuntimeService redis;
    private final JwtUtils jwtUtils;

    public void blacklist(String token) {
        if (token == null || token.isBlank() || !jwtUtils.validateToken(token)) {
            return;
        }
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis > 0) {
            try {
                redis.set(key(token), "1", Duration.ofMillis(ttlMillis));
            } catch (RuntimeException e) {
                // Logout still returns success even if the revocation entry couldn't be
                // written — the token still expires on its own via its normal TTL.
                log.warn("Could not blacklist token (Redis unavailable?): {}", e.getMessage());
            }
        }
    }

    /**
     * Atomically spends a single-use token (refresh rotation, BE-42): one Redis
     * SET NX with the token's remaining lifetime. Two parallel refreshes with the
     * same token can no longer both succeed — only the first claim wins.
     *
     * @return true when this call claimed the token; false when it was already
     * spent or logged out. Fails open on a Redis outage, like the blacklist check.
     */
    public boolean claim(String token) {
        if (token == null || token.isBlank()) return false;
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis <= 0) return false;
        try {
            if (redis.exists(legacyKey(token))) return false;
            return redis.setIfAbsent(key(token), "1", Duration.ofMillis(ttlMillis));
        } catch (RuntimeException e) {
            log.warn("Refresh-token claim failed (Redis unavailable?) — allowing it: {}", e.getMessage());
            return true;
        }
    }

    /**
     * Like {@link #claim} but fails closed (DR-002): with Redis unreachable a
     * refresh or MFA token cannot be checked against logout and reuse, so the
     * caller gets a retryable 503 instead of a fresh session.
     */
    public boolean claimStrict(String token) {
        if (token == null || token.isBlank()) return false;
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis <= 0) return false;
        try {
            if (redis.exists(legacyKey(token))) return false;
            return redis.setIfAbsent(key(token), "1", Duration.ofMillis(ttlMillis));
        } catch (RuntimeException e) {
            log.warn("Token claim unavailable (Redis down?) — refusing: {}", e.getMessage());
            throw new com.aiwa.exception.ServiceUnavailableException("error.try_again_shortly");
        }
    }

    /** {@link #isBlacklisted} that fails closed with a 503 (DR-002); used for refresh and MFA tokens. */
    public boolean isBlacklistedStrict(String token) {
        if (token == null) return false;
        try {
            return redis.exists(key(token)) || redis.exists(legacyKey(token));
        } catch (RuntimeException e) {
            log.warn("Blacklist check unavailable (Redis down?) — refusing: {}", e.getMessage());
            throw new com.aiwa.exception.ServiceUnavailableException("error.try_again_shortly");
        }
    }

    /**
     * Access tokens only (checked on every request): fails open so a Redis
     * outage doesn't sign everyone out. The exposure is bounded by the access
     * token's lifetime (15 minutes since DR-002).
     *
     * @return true only when Redis is reachable AND confirms this exact token was
     * explicitly logged out. A Redis outage/hiccup here must NOT be treated as
     * "blacklisted" — that would silently deauthenticate every signed-in user on
     * every single request the moment Redis has a bad millisecond, even though the
     * JWT's own signature + expiry (checked separately) already establish it's
     * valid. The blacklist is a best-effort extra revocation layer, not the
     * primary trust boundary, so this fails open.
     */
    public boolean isBlacklisted(String token) {
        if (token == null) return false;
        try {
            // Entries written before the SHA-256 key are still honoured until they expire.
            return redis.exists(key(token)) || redis.exists(legacyKey(token));
        } catch (RuntimeException e) {
            log.warn("Blacklist check failed (Redis unavailable?) — treating token as not blacklisted: {}", e.getMessage());
            return false;
        }
    }

    /**
     * SHA-256 of the token. The old key was the 32-bit String.hashCode(), so two
     * different tokens could collide and logging one out could revoke the other.
     */
    static String key(String token) {
        try {
            byte[] digest = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return "jwt:blacklist:v2:" + java.util.HexFormat.of().formatHex(digest);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String legacyKey(String token) {
        return "jwt:blacklist:" + Integer.toHexString(token.hashCode());
    }
}
