package com.aiwa.security;

import com.aiwa.service.impl.RedisRuntimeService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;

/**
 * Per-IP limits on the unauthenticated auth endpoints (brute force, OTP abuse).
 * The client IP is {@code request.getRemoteAddr()}, which behind a reverse proxy
 * is only the real client when {@code server.forward-headers-strategy=native}
 * (set in the prod profile) — otherwise every user would share the proxy's IP
 * and its budget. Per-phone OTP limits live in OtpServiceImpl.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RedisRateLimitFilter extends OncePerRequestFilter {

    /** Path suffix → max POSTs per IP per minute. */
    static final Map<String, Long> LIMITS = Map.of(
            "/auth/login", 10L,
            "/auth/send-otp", 5L,
            "/auth/verify-otp", 10L,
            // Refresh tokens are random and single-use, so there is nothing to
            // brute force; the budget only caps floods. Mobile users share carrier
            // NAT IPs, so a low per-IP cap fails real refreshes (FE-32).
            // ponytail: per-IP key, key on the refresh token if one NAT IP still hits this
            "/auth/refresh", 300L,
            "/auth/register", 5L,
            "/auth/reset-password", 5L,
            "/auth/2fa/verify", 10L);

    private final RedisRuntimeService redis;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = request.getRequestURI();
        Long max = "POST".equalsIgnoreCase(request.getMethod()) ? limitFor(path) : null;
        if (max != null) {
            String ip = request.getRemoteAddr();
            String key = "rate:" + path + ":" + ip;
            // Fail OPEN: a Redis hiccup must not turn into every login attempt being
            // blocked. Rate limiting is a best-effort abuse guard, not the primary
            // auth boundary — losing it briefly is far cheaper than locking everyone
            // out because the counter store stuttered.
            try {
                long count = redis.increment(key, Duration.ofMinutes(1));
                if (count > max) {
                    response.setStatus(429);
                    response.setHeader("Retry-After", "60");
                    response.setContentType("application/json");
                    response.getWriter().write("{\"success\":false,\"status\":429,\"code\":\"error.rate_limited\","
                            + "\"message\":\"Too many requests. Please try again later.\"}");
                    return;
                }
            } catch (RuntimeException e) {
                log.warn("Rate limit check failed (Redis unavailable?) — allowing the request through: {}", e.getMessage());
            }
        }
        filterChain.doFilter(request, response);
    }

    static Long limitFor(String path) {
        for (Map.Entry<String, Long> e : LIMITS.entrySet()) {
            if (path.endsWith(e.getKey())) return e.getValue();
        }
        return null;
    }
}
