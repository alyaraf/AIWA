package com.aiwa.security;

import com.aiwa.service.impl.TokenBlacklistService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Verifies that account status is enforced on EVERY request: a deactivated
 * account presenting a technically-valid JWT must NOT be authenticated.
 */
class JwtAuthFilterTest {

    private final JwtUtils jwtUtils = mock(JwtUtils.class);
    private final UserDetailsService userDetailsService = mock(UserDetailsService.class);
    private final TokenBlacklistService blacklist = mock(TokenBlacklistService.class);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwtUtils, userDetailsService, blacklist);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private void primeValidToken(String identifier) {
        when(blacklist.isBlacklisted("tok")).thenReturn(false);
        when(jwtUtils.validateToken("tok")).thenReturn(true);
        when(jwtUtils.isAccessToken("tok")).thenReturn(true);
        when(jwtUtils.getSubjectFromToken("tok")).thenReturn(identifier);
    }

    private UserDetails userDetails(String identifier, boolean enabled) {
        return new User(identifier, "pw", enabled, true, true, true,
                List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    @Test
    void activeUserIsAuthenticated() throws Exception {
        primeValidToken("active@x.com");
        when(userDetailsService.loadUserByUsername("active@x.com"))
                .thenReturn(userDetails("active@x.com", true));

        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer tok");
        HttpServletResponse res = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilterInternal(req, res, chain);

        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNotNull();
        verify(chain).doFilter(any(HttpServletRequest.class), any(HttpServletResponse.class));
    }

    @Test
    void deactivatedUserIsNotAuthenticatedEvenWithValidToken() throws Exception {
        primeValidToken("suspended@x.com");
        when(userDetailsService.loadUserByUsername("suspended@x.com"))
                .thenReturn(userDetails("suspended@x.com", false)); // isActive=false -> enabled=false

        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer tok");
        HttpServletResponse res = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilterInternal(req, res, chain);

        // Request continues down the chain but WITHOUT authentication -> downstream
        // authorization rejects it with 401/403.
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
        verify(chain).doFilter(any(HttpServletRequest.class), any(HttpServletResponse.class));
    }
}
