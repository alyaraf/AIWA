package com.aiwa.service.impl;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.InvalidTokenException;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
import com.aiwa.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtUtils jwtUtils;
    private final OtpServiceImpl otpService;
    private final TokenBlacklistService tokenBlacklistService;
    private final TotpService totpService;

    @Override
    @Transactional
    public ApiResponse.AuthResponse register(AuthRequest.Register req) {
        if (req.getEmail() != null && userRepository.existsByEmail(req.getEmail())) {
            throw new BusinessException("auth.error.email_taken");
        }
        if (req.getPhone() != null && userRepository.existsByPhone(req.getPhone())) {
            throw new BusinessException("auth.error.phone_taken");
        }
        if (req.getEmail() == null && req.getPhone() == null) {
            throw new BusinessException("auth.error.email_or_phone_required");
        }
        if (req.getRole() == UserRole.ADMIN) {
            throw new BusinessException("auth.error.admin_registration_blocked");
        }
        if (req.getPhone() != null && !otpService.isPhoneVerified(req.getPhone())) {
            throw new BusinessException("auth.error.phone_not_verified");
        }

        User user = User.builder()
                .fullName(req.getFullName())
                .email(req.getEmail())
                .phone(req.getPhone())
                .password(passwordEncoder.encode(req.getPassword()))
                .role(req.getRole())
                .gender(req.getGender())
                .preferredLanguage(req.getPreferredLanguage() != null
                        ? req.getPreferredLanguage()
                        : com.aiwa.enums.Language.EN)
                .active(true)
                .build();

        userRepository.save(user);
        otpService.consumePhoneVerification(req.getPhone());

        String identifier = req.getEmail() != null ? req.getEmail() : req.getPhone();
        return buildAuthResponse(user, identifier);
    }

    @Override
    public ApiResponse.AuthResponse login(AuthRequest.Login req) {
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.getIdentifier(), req.getPassword())
        );

        User user = userRepository.findByEmail(req.getIdentifier())
                .or(() -> userRepository.findByPhone(req.getIdentifier()))
                .orElseThrow(() -> new BadCredentialsException("Invalid credentials"));

        if (user.isTotpEnabled()) {
            // Password checked out, but the account requires a second factor.
            // No access/refresh token is issued yet — only a short-lived,
            // purpose-scoped challenge token that /auth/2fa/verify will exchange
            // for a real session once the TOTP code checks out.
            return ApiResponse.AuthResponse.builder()
                    .mfaRequired(true)
                    .mfaToken(jwtUtils.generateMfaChallengeToken(req.getIdentifier()))
                    .build();
        }

        return buildAuthResponse(user, req.getIdentifier());
    }

    @Override
    public ApiResponse.AuthResponse verifyMfa(String mfaToken, String code) {
        if (mfaToken == null || !jwtUtils.isMfaChallengeToken(mfaToken) || !jwtUtils.validateToken(mfaToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        String identifier = jwtUtils.getSubjectFromToken(mfaToken);
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new InvalidTokenException("auth.error.token_invalid"));

        if (!user.isTotpEnabled() || !totpService.verifyCode(user.getTotpSecret(), code)) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }

        return buildAuthResponse(user, identifier);
    }

    @Override
    public ApiResponse.TwoFactorSetupDto beginTotpSetup(String identifier) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));

        // A fresh secret every time setup is (re)started — it only becomes
        // trusted for login once enableTotp() confirms the user can actually
        // produce a matching code with it.
        String secret = totpService.generateSecret();
        user.setTotpSecret(secret);
        user.setTotpEnabled(false);
        userRepository.save(user);

        String label = user.getEmail() != null ? user.getEmail() : user.getPhone();
        return ApiResponse.TwoFactorSetupDto.builder()
                .secret(secret)
                .otpAuthUri(totpService.buildOtpAuthUri(secret, label, "AIWA"))
                .build();
    }

    @Override
    @Transactional
    public void enableTotp(String identifier, String code) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));

        if (user.getTotpSecret() == null) {
            throw new BusinessException("auth.error.totp_setup_not_started");
        }
        if (!totpService.verifyCode(user.getTotpSecret(), code)) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }
        user.setTotpEnabled(true);
        userRepository.save(user);
    }

    @Override
    @Transactional
    public void disableTotp(String identifier) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));
        user.setTotpEnabled(false);
        user.setTotpSecret(null);
        userRepository.save(user);
    }

    @Override
    public boolean isTotpEnabled(String identifier) {
        return userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"))
                .isTotpEnabled();
    }

    @Override
    public ApiResponse.AuthResponse refreshToken(String refreshToken) {
        // Every failure here means the same thing to a client: drop the stored
        // tokens and show the login screen. InvalidTokenException maps to 401 so
        // that's a status-code check, not a fragile string match on the message.
        if (tokenBlacklistService.isBlacklisted(refreshToken) || !jwtUtils.validateToken(refreshToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        String identifier = jwtUtils.getSubjectFromToken(refreshToken);
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new InvalidTokenException("auth.error.token_invalid"));

        // A deactivated/suspended account must not be able to mint fresh access
        // tokens from a still-valid refresh token.
        if (!user.isActive()) {
            throw new InvalidTokenException("auth.error.account_disabled");
        }

        return buildAuthResponse(user, identifier);
    }

    @Override
    public void logout(String accessToken, String refreshToken) {
        tokenBlacklistService.blacklist(accessToken);
        tokenBlacklistService.blacklist(refreshToken);
    }

    @Override
    public ApiResponse.UserDto getCurrentUser(String identifier) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));
        return toUserDto(user);
    }

    @Override
    @Transactional
    public void resetPassword(AuthRequest.ResetPassword req) {
        // Verifies the OTP (throws if invalid/expired) then sets the new password.
        otpService.verifyOtp(req.getPhone(), req.getCode());

        User user = userRepository.findByPhone(req.getPhone())
                .orElseThrow(() -> new BusinessException("auth.error.phone_not_found"));

        user.setPassword(passwordEncoder.encode(req.getNewPassword()));
        userRepository.save(user);
        otpService.consumePhoneVerification(req.getPhone());

        // Invalidate any outstanding sessions issued before the reset is out of scope
        // for stateless JWTs; the short access-token TTL bounds exposure.
    }

    @Override
    @Transactional
    public void updateLanguage(String identifier, com.aiwa.enums.Language language) {
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));
        user.setPreferredLanguage(language);
        userRepository.save(user);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private ApiResponse.AuthResponse buildAuthResponse(User user, String identifier) {
        String access  = jwtUtils.generateAccessToken(identifier, user.getId(), user.getRole().name());
        String refresh = jwtUtils.generateRefreshToken(identifier);

        return ApiResponse.AuthResponse.builder()
                .accessToken(access)
                .refreshToken(refresh)
                .tokenType("Bearer")
                .user(toUserDto(user))
                .build();
    }

    private ApiResponse.UserDto toUserDto(User u) {
        return ApiResponse.UserDto.builder()
                .id(u.getId())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .preferredLanguage(u.getPreferredLanguage())
                .termsAccepted(u.isTermsAccepted())
                .active(u.isActive())
                .permissions(u.getAdminPermissions() == null ? java.util.List.of()
                        : u.getAdminPermissions().stream().map(Enum::name).sorted().toList())
                .createdAt(u.getCreatedAt())
                .build();
    }
}
