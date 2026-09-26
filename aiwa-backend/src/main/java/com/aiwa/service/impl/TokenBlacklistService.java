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
            return redis.exists(key(token));
        } catch (RuntimeException e) {
            log.warn("Blacklist check failed (Redis unavailable?) — treating token as not blacklisted: {}", e.getMessage());
            return false;
        }
    }

    private String key(String token) {
        return "jwt:blacklist:" + Integer.toHexString(token.hashCode());
    }
}
