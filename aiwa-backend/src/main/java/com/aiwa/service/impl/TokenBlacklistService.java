package com.aiwa.service.impl;

import com.aiwa.entity.RevokedToken;
import com.aiwa.repository.RevokedTokenRepository;
import com.aiwa.security.JwtUtils;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
 * Now a Redis failure falls back to the database instead of failing open.</p>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TokenBlacklistService {

    private final RedisRuntimeService redis;
    private final JwtUtils jwtUtils;
    private final RevokedTokenRepository revokedRepo;

    /** Until when Redis may be missing a revocation that the database has (L-7). */
    private volatile Instant checkDatabaseOnMissUntil = Instant.EPOCH;

    /**
     * SA-06: the same deadline, kept in the database so a restarted or second instance knows
     * it too. It is a row in revoked_tokens under this fixed key, removed when it expires.
     */
    static final String REDIS_GAP_MARKER = "redis-gap-marker";
    private static final Duration GAP_REFRESH = Duration.ofSeconds(5);
    private volatile Instant sharedGapUntil = Instant.EPOCH;
    private volatile Instant sharedGapReadAt = Instant.EPOCH;

    public void blacklist(String token) {
        if (token == null || token.isBlank() || !jwtUtils.validateToken(token)) {
            return;
        }
        long ttlMillis = jwtUtils.getRemainingValidityMillis(token);
        if (ttlMillis <= 0) return;
        try {
            redis.set(key(token), "1", Duration.ofMillis(ttlMillis));
        } catch (RuntimeException e) {
            log.warn("Could not write the token revocation to Redis (the database copy still holds): {}", e.getMessage());
            // AU-14 / L-7: until this token would have expired anyway, a Redis miss is
            // double-checked in the database, or the token works again once Redis is back.
            Instant until = Instant.now().plusMillis(ttlMillis);
            if (until.isAfter(checkDatabaseOnMissUntil)) checkDatabaseOnMissUntil = until;
            recordRedisGap(until);
        }
        try {
            if (!revokedRepo.existsById(hash(token))) {
                revokedRepo.save(new RevokedToken(hash(token), Instant.now().plusMillis(ttlMillis)));
            }
        } catch (RuntimeException e) {
            // Already revoked by a parallel logout: nothing to do.
            log.debug("Token already revoked: {}", e.getMessage());
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
     * Access tokens, checked on every request: Redis first (fast), and the
     * database when Redis can't answer, so an outage neither signs everyone out
     * nor lets a logged-out token back in.
     */
    public boolean isBlacklisted(String token) {
        if (token == null) return false;
        try {
            // Entries written before the SHA-256 key are still honoured until they expire.
            if (redis.exists(key(token)) || redis.exists(legacyKey(token))) return true;
            // A revocation written while Redis was down lives only in the database (L-7).
            return databaseMayHoldMore() && revokedRepo.existsById(hash(token));
        } catch (RuntimeException e) {
            log.warn("Blacklist check: Redis unavailable, using the database: {}", e.getMessage());
            return revokedRepo.existsById(hash(token));
        }
    }

    private boolean databaseMayHoldMore() {
        Instant now = Instant.now();
        if (now.isBefore(checkDatabaseOnMissUntil)) return true;
        if (now.isAfter(sharedGapReadAt.plus(GAP_REFRESH))) {
            try {
                sharedGapUntil = revokedRepo.findById(REDIS_GAP_MARKER)
                        .map(RevokedToken::getExpiresAt).orElse(Instant.EPOCH);
                sharedGapReadAt = now;
            } catch (RuntimeException e) {
                log.warn("Could not read the Redis gap marker: {}", e.getMessage());
            }
        }
        return now.isBefore(sharedGapUntil);
    }

    private void recordRedisGap(Instant until) {
        try {
            var existing = revokedRepo.findById(REDIS_GAP_MARKER);
            if (existing.isPresent() && !existing.get().getExpiresAt().isBefore(until)) return;
            existing.ifPresent(m -> revokedRepo.deleteById(REDIS_GAP_MARKER));
            revokedRepo.saveAndFlush(new RevokedToken(REDIS_GAP_MARKER, until));
        } catch (RuntimeException e) {
            log.warn("Could not record the Redis gap marker: {}", e.getMessage());
        }
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
