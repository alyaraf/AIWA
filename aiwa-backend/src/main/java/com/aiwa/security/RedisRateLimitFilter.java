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

@Slf4j
@Component
@RequiredArgsConstructor
public class RedisRateLimitFilter extends OncePerRequestFilter {

    private final RedisRuntimeService redis;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String path = request.getRequestURI();
        if ("POST".equalsIgnoreCase(request.getMethod()) && isLimitedAuthPath(path)) {
            String ip = request.getRemoteAddr();
            String key = "rate:" + path + ":" + ip;
            long max = path.endsWith("/send-otp") ? 5 : 10;
            // Fail OPEN: a Redis hiccup must not turn into every login attempt being
            // blocked. Rate limiting is a best-effort abuse guard, not the primary
            // auth boundary — losing it briefly is far cheaper than locking everyone
            // out because the counter store stuttered.
            try {
                long count = redis.increment(key, Duration.ofMinutes(1));
                if (count > max) {
                    response.setStatus(429);
                    response.setContentType("application/json");
                    response.getWriter().write("{\"success\":false,\"message\":\"Too many requests. Please try again later.\"}");
                    return;
                }
            } catch (RuntimeException e) {
                log.warn("Rate limit check failed (Redis unavailable?) — allowing the request through: {}", e.getMessage());
            }
        }
        filterChain.doFilter(request, response);
    }

    private boolean isLimitedAuthPath(String path) {
        return path.endsWith("/auth/login")
                || path.endsWith("/auth/send-otp")
                || path.endsWith("/auth/verify-otp")
                || path.endsWith("/auth/refresh");
    }
}
