package com.aiwa.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import com.aiwa.service.impl.TokenBlacklistService;

import java.io.IOException;

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtils jwtUtils;
    private final UserDetailsService userDetailsService;
    private final TokenBlacklistService tokenBlacklistService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String token = extractToken(request);
            // Only ACCESS tokens authenticate a request. Refresh tokens and the MFA
            // challenge token are signed with the same key, so without this check
            // either one could be replayed here as a bearer token.
            if (token != null && !tokenBlacklistService.isBlacklisted(token)
                    && jwtUtils.validateToken(token) && jwtUtils.isAccessToken(token)) {
                String identifier = jwtUtils.getSubjectFromToken(token);
                UserDetails userDetails;
                try {
                    userDetails = userDetailsService.loadUserByUsername(identifier);
                } catch (org.springframework.security.core.userdetails.UsernameNotFoundException e) {
                    // The account's sign-in email changed since this token was issued.
                    Long userId = jwtUtils.getUserIdFromToken(token);
                    if (userId == null || !(userDetailsService instanceof UserDetailsServiceImpl impl)) throw e;
                    userDetails = impl.loadUserById(userId);
                }

                // Tokens minted before a password reset / admin deactivation are dead.
                boolean sessionCurrent = !(userDetails instanceof AiwaUserDetails aiwa)
                        || aiwa.acceptsTokenIssuedAt(jwtUtils.getIssuedAt(token));

                // Enforce account status on EVERY request: a deactivated/suspended
                // account (isActive=false → enabled=false) must not be authenticated,
                // even when it presents a technically-valid, unexpired JWT.
                if (!sessionCurrent) {
                    log.warn("Rejected token issued before the session cut-off for {}", identifier);
                } else if (userDetails.isEnabled() && userDetails.isAccountNonLocked()) {
                    UsernamePasswordAuthenticationToken auth =
                            new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                } else {
                    log.warn("Rejected request for disabled account: {}", identifier);
                }
            }
        } catch (Exception e) {
            log.error("Cannot set user authentication: {}", e.getMessage());
        }
        filterChain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        if (request.getCookies() != null) {
            for (Cookie cookie : request.getCookies()) {
                if ("accessToken".equals(cookie.getName()) && StringUtils.hasText(cookie.getValue())) {
                    return cookie.getValue();
                }
            }
        }
        return null;
    }
}
