package com.aiwa.service.impl;

import com.aiwa.entity.RevokedToken;
import com.aiwa.repository.RevokedTokenRepository;
import com.aiwa.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.aiwa.exception.ServiceUnavailableException;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Logged-out and spent tokens (logout, refresh rotation, single-use MFA
 * challenges).
 *
 * <p>DR-002: the database is the record; Redis is a fast first check in front
 * of it. Before, everything lived in Redis only, and during a Redis outage a
 * logged-out token kept working and a spent refresh token could be reused.
 * Now a Redis failure falls back to the database instead of failing open. SEC-01: a Redis
 * miss is no longer trusted either; the database settles every miss.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TokenBlacklistService {

    private final RedisRuntimeService redis;
    private final JwtUtils jwtUtils;
    private final RevokedTokenRepository revokedRepo;

    /**
     * Revokes a logged-out token durably. The database row is the revocation (SEC-02): this
     * returns normally only once that row exists, whether this call wrote it or a parallel
     * logout already had. When the database cannot confirm it, a ServiceUnavailableException
     * is thrown so the caller can say so instead of promising a revocation that will not
     * survive a Redis restart. The Redis copy is a best-effort accelerator.
     *
     * <p>A token that is already unusable (malformed, wrongly signed, expired) has nothing
     * to revoke and is ignored.</p>
     */
    public void revoke(String token) {
        if (token == null || token.isBlank() || !jwtUtils.validateToken(token)) {
            return;
        }
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis <= 0) return;
        String hash = hash(token);
        boolean durable = true;
        try {
            persist(hash, ttlMillis);
        } catch (RuntimeException e) {
            durable = false;
            log.error("TOKEN_REVOCATION_NOT_DURABLE the revoked-token row could not be confirmed: {}", e.toString());
        }
        try {
            redis.set(key(token), "1", Duration.ofMillis(ttlMillis));
        } catch (RuntimeException e) {
            log.warn("Could not write the token revocation to Redis (the database decides on a miss): {}", e.getMessage());
        }
        if (!durable) {
            throw new ServiceUnavailableException("auth.error.logout_revocation_failed");
        }
    }

    /** Inserts the row; a row that is already there (parallel or repeated logout) counts as revoked. */
    private void persist(String hash, long ttlMillis) {
        if (revokedRepo.existsById(hash)) return;
        try {
            revokedRepo.saveAndFlush(new RevokedToken(hash, Instant.now().plusMillis(ttlMillis)));
        } catch (org.springframework.dao.DataIntegrityViolationException
                 | jakarta.persistence.EntityExistsException e) {
            // Only a duplicate key is benign, and only if the row really is there.
            if (!revokedRepo.existsById(hash)) throw e;
        }
    }

    /**
     * Atomically spends a single-use token (refresh rotation BE-42, MFA
     * challenge): an INSERT on the token's hash, so of two parallel uses only
     * one succeeds, with or without Redis.
     *
     * @return true when this call spent the token; false when it was already
     * spent or logged out
     */
    public boolean claimStrict(String token) {
        if (token == null || token.isBlank()) return false;
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis <= 0) return false;
        try {
            if (redis.exists(legacyKey(token))) return false;
        } catch (RuntimeException e) {
            log.debug("Legacy blacklist check skipped (Redis down): {}", e.getMessage());
        }
        try {
            revokedRepo.saveAndFlush(new RevokedToken(hash(token), Instant.now().plusMillis(ttlMillis)));
        } catch (org.springframework.dao.DataIntegrityViolationException
                 | jakarta.persistence.EntityExistsException e) {
            return false;
        }
        try {
            redis.set(key(token), "1", Duration.ofMillis(ttlMillis));
        } catch (RuntimeException e) {
            log.debug("Redis copy of the spent token not written: {}", e.getMessage());
        }
        return true;
    }

    /** Refresh and MFA tokens: the database record decides. */
    public boolean isBlacklistedStrict(String token) {
        if (token == null) return false;
        return revokedRepo.existsById(hash(token)) || legacyRevoked(token);
    }

    /**
     * Access tokens, checked on every request. Redis answers a revoked token quickly, but a
     * Redis miss proves nothing (SEC-01): a restart, an eviction, a lost AOF second or another
     * instance's empty cache all look like a miss. So a miss is always settled by the database,
     * the record of revocation. A database failure propagates and the request stays
     * unauthenticated, rather than guessing the token is fine.
     */
    public boolean isBlacklisted(String token) {
        if (token == null) return false;
        try {
            // Entries written before the SHA-256 key are still honoured until they expire.
            if (redis.exists(key(token)) || redis.exists(legacyKey(token))) return true;
        } catch (RuntimeException e) {
            log.warn("Blacklist check: Redis unavailable, using the database: {}", e.getMessage());
        }
        return revokedRepo.existsById(hash(token));
    }

    /** Removes records of tokens that have expired anyway. */
    public int purgeExpired() {
        return revokedRepo.deleteExpired(Instant.now());
    }

    private boolean legacyRevoked(String token) {
        try {
            return redis.exists(legacyKey(token));
        } catch (RuntimeException e) {
            return false; // legacy entries were Redis-only and expire within days
        }
    }

    static String hash(String token) {
        try {
            byte[] digest = java.security.MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return java.util.HexFormat.of().formatHex(digest);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    /**
     * SHA-256 of the token. The old key was the 32-bit String.hashCode(), so two
     * different tokens could collide and logging one out could revoke the other.
     */
    static String key(String token) {
        return "jwt:blacklist:v2:" + hash(token);
    }

    private static String legacyKey(String token) {
        return "jwt:blacklist:" + Integer.toHexString(token.hashCode());
    }
}
