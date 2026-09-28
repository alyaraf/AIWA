package com.aiwa.service;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.dto.response.ApiResponse;

// ponytail: one implementation (AuthServiceImpl), inline into a concrete @Service when touched; keep only if a second impl appears
public interface AuthService {
    ApiResponse.AuthResponse register(AuthRequest.Register request);
    ApiResponse.AuthResponse login(AuthRequest.Login request);
    ApiResponse.AuthResponse refreshToken(String refreshToken);
    void logout(String accessToken, String refreshToken);
    ApiResponse.UserDto getCurrentUser(String identifier);
    void updateLanguage(String identifier, com.aiwa.enums.Language language);
    void resetPassword(AuthRequest.ResetPassword request);

    // ── Two-factor authentication (TOTP) ────────────────────────────────────
    ApiResponse.AuthResponse verifyMfa(String mfaToken, String code);
    ApiResponse.TwoFactorSetupDto beginTotpSetup(String identifier);
    void enableTotp(String identifier, String code);
    void disableTotp(String identifier);
    boolean isTotpEnabled(String identifier);
}
