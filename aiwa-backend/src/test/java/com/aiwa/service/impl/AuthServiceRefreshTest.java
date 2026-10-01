package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.InvalidTokenException;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

/**
 * A deactivated account must not be able to mint fresh access tokens from a
 * still-valid refresh token.
 */
class AuthServiceRefreshTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final AuthenticationManager authManager = mock(AuthenticationManager.class);
    private final JwtUtils jwtUtils = mock(JwtUtils.class);
    private final OtpServiceImpl otpService = mock(OtpServiceImpl.class);
    private final TokenBlacklistService blacklist = mock(TokenBlacklistService.class);
    private final TotpService totpService = mock(TotpService.class);

    private final AuthServiceImpl service =
            new AuthServiceImpl(userRepo, mock(com.aiwa.repository.ProviderProfileRepository.class), encoder, authManager, jwtUtils, otpService, blacklist, totpService);

    private void primeToken(String identifier) {
        when(blacklist.isBlacklistedStrict("refresh")).thenReturn(false);
        when(jwtUtils.validateToken("refresh")).thenReturn(true);
        when(jwtUtils.isRefreshToken("refresh")).thenReturn(true);
        when(jwtUtils.getSubjectFromToken("refresh")).thenReturn(identifier);
        when(jwtUtils.getUserIdFromToken("refresh")).thenReturn(null); // a token from before the userId claim
        when(blacklist.claimStrict("refresh")).thenReturn(true);
    }

    @Test
    void anAccessOrMfaTokenCannotBeUsedToRefresh() {
        primeToken("live@x.com");
        when(jwtUtils.isRefreshToken("refresh")).thenReturn(false);

        assertThatThrownBy(() -> service.refreshToken("refresh"))
                .isInstanceOf(InvalidTokenException.class);
        verifyNoInteractions(userRepo);
    }

    @Test
    void refreshRotatesTheUsedToken() {
        primeToken("live@x.com");
        User active = User.builder().id(1L).email("live@x.com").role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByLogin("live@x.com")).thenReturn(Optional.of(active));
        when(jwtUtils.generateAccessToken("live@x.com", 1L, "CUSTOMER")).thenReturn("access");
        when(jwtUtils.generateRefreshToken("live@x.com", 1L)).thenReturn("newRefresh");

        service.refreshToken("refresh");

        // The old refresh token is spent, so a stolen copy can't mint sessions in parallel.
        verify(blacklist).claimStrict("refresh");
    }

    @Test
    void aSecondConcurrentUseOfTheSameRefreshTokenIsRejected() {
        primeToken("live@x.com");
        User active = User.builder().id(1L).email("live@x.com").role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByLogin("live@x.com")).thenReturn(Optional.of(active));
        // The other request claimed it first (Redis SET NX lost).
        when(blacklist.claimStrict("refresh")).thenReturn(false);

        assertThatThrownBy(() -> service.refreshToken("refresh"))
                .isInstanceOf(InvalidTokenException.class);
        verify(jwtUtils, never()).generateRefreshToken(any(), any());
    }

    /**
     * V-01: a refresh token names its account by id. Someone who later sets
     * their email to this user's phone number can't capture the refresh.
     */
    @Test
    void refreshResolvesTheAccountByTheTokensUserIdNotItsSubject() {
        primeToken("+201000000001");
        when(jwtUtils.getUserIdFromToken("refresh")).thenReturn(1L);
        User owner = User.builder().id(1L).phone("+201000000001").role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(1L)).thenReturn(Optional.of(owner));
        when(jwtUtils.generateAccessToken("+201000000001", 1L, "CUSTOMER")).thenReturn("access");
        when(jwtUtils.generateRefreshToken("+201000000001", 1L)).thenReturn("newRefresh");

        service.refreshToken("refresh");

        verify(userRepo, never()).findByLogin(any());
        verify(jwtUtils).generateAccessToken("+201000000001", 1L, "CUSTOMER");
    }

    /** DR-018: the cut-off is compared to the millisecond. */
    @Test
    void refreshTokenIssuedEarlierInTheSameSecondAsTheCutOffIsRejected() {
        primeToken("live@x.com");
        User active = User.builder().id(1L).email("live@x.com").role(UserRole.CUSTOMER).active(true)
                .tokensValidAfter(java.time.Instant.parse("2026-09-29T10:00:00.700Z")).build();
        when(userRepo.findByLogin("live@x.com")).thenReturn(Optional.of(active));
        when(jwtUtils.getIssuedAt("refresh")).thenReturn(java.time.Instant.parse("2026-09-29T10:00:00.200Z"));

        assertThatThrownBy(() -> service.refreshToken("refresh"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void refreshTokenIssuedBeforeAPasswordResetIsRejected() {
        primeToken("live@x.com");
        User active = User.builder().id(1L).email("live@x.com").role(UserRole.CUSTOMER).active(true)
                .tokensValidAfter(java.time.Instant.parse("2026-09-29T10:00:00Z")).build();
        when(userRepo.findByLogin("live@x.com")).thenReturn(Optional.of(active));
        when(jwtUtils.getIssuedAt("refresh")).thenReturn(java.time.Instant.parse("2026-09-29T09:59:00Z"));

        assertThatThrownBy(() -> service.refreshToken("refresh"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void refreshRejectedForDeactivatedUser() {
        primeToken("gone@x.com");
        User inactive = User.builder().id(9L).email("gone@x.com")
                .role(UserRole.CUSTOMER).active(false).build();
        when(userRepo.findByLogin("gone@x.com")).thenReturn(Optional.of(inactive));

        // Mapped to a dedicated exception (→ 401) rather than the generic
        // BusinessException (→ 400) so a mobile client can rely on the status
        // code alone to know "drop tokens and show login".
        assertThatThrownBy(() -> service.refreshToken("refresh"))
                .isInstanceOf(InvalidTokenException.class)
                .hasMessageContaining("account_disabled");
    }

    @Test
    void refreshSucceedsForActiveUser() {
        primeToken("live@x.com");
        User active = User.builder().id(1L).email("live@x.com")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByLogin("live@x.com")).thenReturn(Optional.of(active));
        when(jwtUtils.generateAccessToken("live@x.com", 1L, "CUSTOMER")).thenReturn("access");
        when(jwtUtils.generateRefreshToken("live@x.com", 1L)).thenReturn("newRefresh");

        ApiResponse.AuthResponse resp = service.refreshToken("refresh");
        assertThat(resp.getAccessToken()).isEqualTo("access");
        assertThat(resp.getRefreshToken()).isEqualTo("newRefresh");
    }
}
