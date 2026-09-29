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
