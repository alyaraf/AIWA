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
import org.springframework.web.util.UrlPathHelper;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;

/**
 * Per-IP limits on the unauthenticated auth endpoints (brute force, OTP abuse)
 * and on the public nearby search (RV-01).
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
            "/auth/2fa/verify", 10L,
            // SEC-03: endpoint/IP throttle on top of the per-enrollment attempt budget.
            "/auth/2fa/enable", 10L,
            "/auth/2fa/setup", 10L);

    /** Path suffix → max GETs per IP per minute. */
    static final Map<String, Long> GET_LIMITS = Map.of(
            // RV-01: public and location-based, so a cap on grid probing. A map pan is a few calls.
            "/providers/nearby", 120L);

    private final RedisRuntimeService redis;
    private final com.aiwa.util.LocalWindowCounter localFallback = new com.aiwa.util.LocalWindowCounter();
    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMeterRegistry(io.micrometer.core.instrument.MeterRegistry registry) {
        this.meterRegistry = registry;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        // CR-01: the decoded path, the one Spring MVC routes on. The raw request URI
        // let "/auth/logi%6e" reach the login handler with no limit at all.
        String path = UrlPathHelper.defaultInstance.getPathWithinApplication(request);
        String method = request.getMethod();
        Long max = "POST".equalsIgnoreCase(method) ? limitFor(path, LIMITS)
                : "GET".equalsIgnoreCase(method) ? limitFor(path, GET_LIMITS) : null;
        if (max != null) {
            String ip = request.getRemoteAddr();
            String key = "rate:" + path + ":" + ip;
            // A Redis hiccup must not turn into every login attempt being blocked, and must not
            // switch the limits off either (S-07): the same limit is counted in this process
            // instead (per instance, so weaker than Redis, never absent), and the outage is
            // counted for the RateLimitRedisUnavailable alert.
            try {
                long count;
                try {
                    count = redis.increment(key, Duration.ofMinutes(1));
                } catch (RuntimeException e) {
                    count = localFallback.increment(key, Duration.ofMinutes(1));
                    if (meterRegistry != null) {
                        meterRegistry.counter("aiwa.ratelimit.redis.unavailable", "scope", "ip").increment();
                    }
                    log.error("RATE_LIMIT_REDIS_UNAVAILABLE scope=ip path={} - enforcing the limit in-process: {}", com.aiwa.util.LogSafe.oneLine(path), e.getMessage());
                }
                if (count > max) {
                    response.setStatus(429);
                    response.setHeader("Retry-After", "60");
                    response.setContentType("application/json");
                    response.getWriter().write("{\"success\":false,\"status\":429,\"code\":\"error.rate_limited\","
                            + "\"message\":\"Too many requests. Please try again later.\"}");
                    return;
                }
            } catch (RuntimeException e) {
                log.warn("Rate limit check failed unexpectedly — allowing the request through: {}", e.getMessage());
            }
        }
        filterChain.doFilter(request, response);
    }

    static Long limitFor(String path, Map<String, Long> limits) {
        for (Map.Entry<String, Long> e : limits.entrySet()) {
            if (path.endsWith(e.getKey())) return e.getValue();
        }
        return null;
    }
}
