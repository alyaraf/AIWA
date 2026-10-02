package com.aiwa.service;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.dto.response.ApiResponse;

// ponytail: one implementation (AuthServiceImpl), inline into a concrete @Service when touched; keep only if a second impl appears
public interface AuthService {
    ApiResponse.AuthResponse register(AuthRequest.Register request);
    ApiResponse.AuthResponse login(AuthRequest.Login request);
    ApiResponse.AuthResponse refreshToken(String refreshToken);
    ApiResponse.AuthResponse changePhone(String identifier, AuthRequest.ChangePhone request);
    /** CR-05: the current password, for a sensitive change. A wrong one counts toward the sign-in lock. */
    void confirmPassword(String identifier, String password);
    /** CR-05: moves the pending email to the account once its code checks out; ends every other session. */
    ApiResponse.AuthResponse confirmEmail(String identifier, String code);
    void logout(String accessToken, String refreshToken);
    ApiResponse.UserDto getCurrentUser(String identifier);
    void updateLanguage(String identifier, com.aiwa.enums.Language language);
    void resetPassword(AuthRequest.ResetPassword request);

    // ── Two-factor authentication (TOTP) ────────────────────────────────────
    ApiResponse.AuthResponse verifyMfa(String mfaToken, String code);
    ApiResponse.TwoFactorSetupDto beginTotpSetup(String identifier, String password, String code);
    void enableTotp(String identifier, String code);
    void disableTotp(String identifier, String password, String code);
    boolean isTotpEnabled(String identifier);
}
