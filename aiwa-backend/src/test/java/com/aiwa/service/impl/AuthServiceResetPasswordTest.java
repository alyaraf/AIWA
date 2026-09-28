package com.aiwa.service.impl;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

class AuthServiceResetPasswordTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final AuthenticationManager authManager = mock(AuthenticationManager.class);
    private final JwtUtils jwtUtils = mock(JwtUtils.class);
    private final OtpServiceImpl otpService = mock(OtpServiceImpl.class);
    private final TokenBlacklistService blacklist = mock(TokenBlacklistService.class);
    private final TotpService totpService = mock(TotpService.class);

    private final AuthServiceImpl service =
            new AuthServiceImpl(userRepo, mock(com.aiwa.repository.ProviderProfileRepository.class), encoder, authManager, jwtUtils, otpService, blacklist, totpService);

    private AuthRequest.ResetPassword req() {
        AuthRequest.ResetPassword r = new AuthRequest.ResetPassword();
        r.setPhone("+201000000000");
        r.setCode("123456");
        r.setNewPassword("newSecret1");
        return r;
    }

    @Test
    void resetsPasswordAfterOtpVerified() {
        User u = User.builder().id(5L).phone("+201000000000").role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByPhone("+201000000000")).thenReturn(Optional.of(u));
        when(encoder.encode("newSecret1")).thenReturn("hashed");

        service.resetPassword(req());

        verify(otpService).verifyOtp("+201000000000", "123456");
        verify(userRepo).save(argThat(saved -> "hashed".equals(saved.getPassword())));
        verify(otpService).consumePhoneVerification("+201000000000");
    }

    @Test
    void failsWhenOtpInvalid() {
        doThrow(new BusinessException("Invalid or expired code"))
                .when(otpService).verifyOtp(anyString(), anyString());

        assertThatThrownBy(() -> service.resetPassword(req()))
                .isInstanceOf(BusinessException.class);
        verify(userRepo, never()).save(any());
    }

    @Test
    void failsWhenNoAccountForPhone() {
        when(userRepo.findByPhone("+201000000000")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.resetPassword(req()))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("phone_not_found");
    }
}
