package com.aiwa.service.impl;

import com.aiwa.entity.RevokedToken;
import com.aiwa.repository.RevokedTokenRepository;
import com.aiwa.security.AiwaUserDetails;
import com.aiwa.security.JwtAuthFilter;
import com.aiwa.security.JwtUtils;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.util.ReflectionTestUtils;
import java.util.List;
import java.util.Optional;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Audit probes assert the current defects, not desired behavior. Synthetic tokens only. */
class SecurityRevocationAuditTest {
    private JwtUtils jwt() {
        JwtUtils jwt = new JwtUtils();
        ReflectionTestUtils.setField(jwt, "jwtSecret", "audit-only-test-signing-key-32-bytes-minimum");
        ReflectionTestUtils.setField(jwt, "jwtExpiration", 900_000L);
        return jwt;
    }

    @Test
    void healthyRedisMissReauthenticatesAnAccessTokenStillRevokedInDatabase() throws Exception {
        JwtUtils jwt = jwt();
        String token = jwt.generateAccessToken("audit-user@example.invalid", 17L, "CUSTOMER");
        RedisRuntimeService redis = mock(RedisRuntimeService.class);
        RevokedTokenRepository repo = mock(RevokedTokenRepository.class);
        when(redis.exists(anyString())).thenReturn(false);
        when(repo.findById(TokenBlacklistService.REDIS_GAP_MARKER)).thenReturn(Optional.empty());
        when(repo.existsById(TokenBlacklistService.hash(token))).thenReturn(false);
        TokenBlacklistService service = new TokenBlacklistService(redis, jwt, repo);
        // Healthy normal logout writes both stores, with no gap marker. Later Redis loses only the entry.
        when(repo.save(any(RevokedToken.class))).thenAnswer(inv -> inv.getArgument(0));
        service.blacklist(token);
        verify(repo).save(argThat(row -> row.getTokenHash().equals(TokenBlacklistService.hash(token))));
        when(repo.existsById(TokenBlacklistService.hash(token))).thenReturn(true);
        assertThat(service.isBlacklistedStrict(token)).isTrue();
        assertThat(service.isBlacklisted(token)).isFalse();
        UserDetailsService users = mock(UserDetailsService.class);
        when(users.loadUserByUsername("audit-user@example.invalid")).thenReturn(
            new AiwaUserDetails(17L, "audit-user@example.invalid", "unused", true,
                List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")), null));
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/auth/me");
        request.addHeader("Authorization", "Bearer " + token);
        try {
            new JwtAuthFilter(jwt, users, service).doFilter(request, new MockHttpServletResponse(), (req, res) -> {});
            assertThat(SecurityContextHolder.getContext().getAuthentication()).isNotNull();
            assertThat(SecurityContextHolder.getContext().getAuthentication().getName()).isEqualTo("audit-user@example.invalid");
        } finally { SecurityContextHolder.clearContext(); }
        System.out.println("AUDIT cache-loss: DB-revoked access token authenticated after healthy Redis miss");
    }

    @Test
    void failureOfBothRevocationStoresIsReportedAsSuccessfulLogout() {
        JwtUtils jwt = jwt();
        String token = jwt.generateAccessToken("audit-user@example.invalid", 17L, "CUSTOMER");
        RedisRuntimeService redis = mock(RedisRuntimeService.class);
        RevokedTokenRepository repo = mock(RevokedTokenRepository.class);
        doThrow(new IllegalStateException("injected Redis unavailable")).when(redis).set(anyString(), anyString(), any());
        when(repo.findById(anyString())).thenThrow(new DataAccessResourceFailureException("injected DB unavailable"));
        when(repo.existsById(anyString())).thenThrow(new DataAccessResourceFailureException("injected DB unavailable"));
        when(repo.saveAndFlush(any())).thenThrow(new DataAccessResourceFailureException("injected DB unavailable"));
        TokenBlacklistService service = new TokenBlacklistService(redis, jwt, repo);
        AuthServiceImpl auth = new AuthServiceImpl(null, null, null, null, jwt, null, service, null);
        com.aiwa.controller.AuthController controller = new com.aiwa.controller.AuthController(auth, null, null, null, null, jwt, null, null, null);
        ReflectionTestUtils.setField(controller, "contextPath", "/api");
        assertThat(controller.logout("Bearer " + token, null, null, null).getStatusCode().value()).isEqualTo(200);
        // Both stores recover without any successful token write.
        when(redis.exists(anyString())).thenReturn(false);
        doReturn(false).when(repo).existsById(anyString());
        doReturn(Optional.empty()).when(repo).findById(anyString());
        assertThat(service.isBlacklisted(token)).isFalse();
        assertThat(service.isBlacklistedStrict(token)).isFalse();
        System.out.println("AUDIT double-store-failure: logout returns normally; token is unrevoked after recovery");
    }
}
