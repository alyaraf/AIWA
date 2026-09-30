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

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final com.aiwa.repository.ProviderProfileRepository providerProfileRepo;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtUtils jwtUtils;
    private final OtpServiceImpl otpService;
    private final TokenBlacklistService tokenBlacklistService;
    private final TotpService totpService;

    @Override
    @Transactional
    public ApiResponse.AuthResponse register(AuthRequest.Register req) {
        String email = blankToNull(req.getEmail());
        String phone = blankToNull(req.getPhone());
        if (email != null && userRepository.existsByEmail(email)) {
            throw new BusinessException("auth.error.email_taken");
        }
        if (phone != null && userRepository.existsByPhone(phone)) {
            throw new BusinessException("auth.error.phone_taken");
        }
        if (email == null && phone == null) {
            throw new BusinessException("auth.error.email_or_phone_required");
        }
        if (req.getRole() == UserRole.ADMIN) {
            throw new BusinessException("auth.error.admin_registration_blocked");
        }
        if (phone != null && !otpService.isPhoneVerified(phone)) {
            throw new BusinessException("auth.error.phone_not_verified");
        }
        // An email-only account must prove it owns the address (email OTP, BE-10);
        // before, any unverified address could be registered.
        if (phone == null && !otpService.isEmailVerified(email)) {
            throw new BusinessException("auth.error.email_not_verified");
        }

        User user = User.builder()
                .fullName(req.getFullName().trim())
                .email(email)
                .phone(phone)
                .password(passwordEncoder.encode(req.getPassword()))
                .role(req.getRole())
                .gender(req.getGender())
                .preferredLanguage(req.getPreferredLanguage() != null
                        ? req.getPreferredLanguage()
                        : com.aiwa.enums.Language.EN)
                .active(true)
                .build();

        userRepository.save(user);
        otpService.consumePhoneVerification(phone);
        if (phone == null) otpService.consumeEmailVerification(email);

        String identifier = email != null ? email : phone;
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
        if (mfaToken == null || tokenBlacklistService.isBlacklisted(mfaToken)
                || !jwtUtils.isMfaChallengeToken(mfaToken) || !jwtUtils.validateToken(mfaToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        String identifier = jwtUtils.getSubjectFromToken(mfaToken);
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new InvalidTokenException("auth.error.token_invalid"));
        if (!user.isActive()) {
            throw new InvalidTokenException("auth.error.account_disabled");
        }

        if (!user.isTotpEnabled() || !totpService.verifyCode(user.getTotpSecret(), code)) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }

        // The challenge token is single-use: once exchanged it can't mint a second session.
        tokenBlacklistService.blacklist(mfaToken);
        return buildAuthResponse(user, identifier);
    }

    @Override
    public ApiResponse.TwoFactorSetupDto beginTotpSetup(String identifier) {
        User user = findUser(identifier);

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
        User user = findUser(identifier);

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
        User user = findUser(identifier);
        user.setTotpEnabled(false);
        user.setTotpSecret(null);
        userRepository.save(user);
    }

    @Override
    public boolean isTotpEnabled(String identifier) {
        return findUser(identifier).isTotpEnabled();
    }

    /**
     * Exchange a refresh token for a new pair. Only a real refresh token is
     * accepted (not an access or MFA token), tokens issued before the account's
     * session cut-off are refused, and the used refresh token is revoked
     * (rotation) so a stolen copy can't keep minting sessions in parallel.
     */
    @Override
    public ApiResponse.AuthResponse refreshToken(String refreshToken) {
        // Every failure here means the same thing to a client: drop the stored
        // tokens and show the login screen. InvalidTokenException maps to 401 so
        // that's a status-code check, not a fragile string match on the message.
        if (tokenBlacklistService.isBlacklisted(refreshToken) || !jwtUtils.validateToken(refreshToken)
                || !jwtUtils.isRefreshToken(refreshToken)) {
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
        if (user.getTokensValidAfter() != null) {
            Instant issued = jwtUtils.getIssuedAt(refreshToken);
            if (issued == null || issued.isBefore(user.getTokensValidAfter().truncatedTo(ChronoUnit.SECONDS))) {
                throw new InvalidTokenException("auth.error.token_invalid");
            }
        }

        // Spend the token atomically before minting new ones: of two parallel
        // refreshes with the same token only one gets a new pair (BE-42).
        if (!tokenBlacklistService.claim(refreshToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
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
        return toUserDto(findUser(identifier));
    }

    /**
     * Forgot password, by phone or email. Every session issued before the reset
     * is revoked — someone who reset because their password leaked must not stay
     * signed in on the attacker's device.
     */
    @Override
    @Transactional
    public void resetPassword(AuthRequest.ResetPassword req) {
        User user;
        String phone = blankToNull(req.getPhone());
        if (phone != null) {
            // Verifies the OTP (throws if invalid/expired) then sets the new password.
            otpService.verifyOtp(phone, req.getCode());
            user = userRepository.findByPhone(phone)
                    .orElseThrow(() -> new BusinessException("auth.error.phone_not_found"));
        } else {
            String email = blankToNull(req.getEmail());
            if (email == null) throw new BusinessException("auth.error.email_or_phone_required");
            otpService.verifyEmailOtp(email, req.getCode());
            user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new BusinessException("auth.error.email_not_found"));
        }

        user.setPassword(passwordEncoder.encode(req.getNewPassword()));
        user.setTokensValidAfter(Instant.now());
        userRepository.save(user);
        if (phone != null) otpService.consumePhoneVerification(phone);
        else otpService.consumeEmailVerification(req.getEmail());
    }

    /**
     * Change the account phone (BE-19). The new number must pass OTP first. Old
     * sessions are revoked — a phone-based login's token subject is the old
     * number — and a fresh token pair for the new identity is returned.
     */
    @Override
    @Transactional
    public ApiResponse.AuthResponse changePhone(String identifier, AuthRequest.ChangePhone req) {
        User user = findUser(identifier);
        String phone = req.getPhone().trim();
        if (phone.equals(user.getPhone())) {
            throw new BusinessException("auth.error.phone_unchanged");
        }
        if (userRepository.existsByPhone(phone)) {
            throw new BusinessException("auth.error.phone_taken");
        }
        otpService.verifyOtp(phone, req.getCode());
        otpService.consumePhoneVerification(phone);

        user.setPhone(phone);
        user.setTokensValidAfter(Instant.now());
        userRepository.save(user);
        String newIdentifier = user.getEmail() != null ? user.getEmail() : phone;
        return buildAuthResponse(user, newIdentifier);
    }

    @Override
    @Transactional
    public void updateLanguage(String identifier, com.aiwa.enums.Language language) {
        User user = findUser(identifier);
        user.setPreferredLanguage(language);
        userRepository.save(user);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private User findUser(String identifier) {
        return userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new BusinessException("user.not_found"));
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

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
        // Lets the app gate unapproved providers on the pending screen.
        var provider = u.getRole() == com.aiwa.enums.UserRole.PROVIDER
                ? providerProfileRepo.findByUserId(u.getId()).orElse(null) : null;
        return ApiResponse.UserDto.builder()
                .providerProfileId(provider == null ? null : provider.getId())
                .providerStatus(provider == null ? null : provider.getVerificationStatus())
                .providerNote(provider == null ? null : provider.getRejectionReason())
                .id(u.getId())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .preferredLanguage(u.getPreferredLanguage())
                .termsAccepted(u.isTermsAccepted())
                .acceptedTermsVersion(u.getAcceptedTermsVersion())
                .termsAcceptedAt(u.getTermsAcceptedAt())
                .searchAreaLabel(u.getSearchAreaLabel())
                .searchAreaLatitude(u.getSearchAreaLatitude())
                .searchAreaLongitude(u.getSearchAreaLongitude())
                .active(u.isActive())
                .permissions(u.getAdminPermissions() == null ? java.util.List.of()
                        : u.getAdminPermissions().stream().map(Enum::name).sorted().toList())
                .createdAt(u.getCreatedAt())
                .build();
    }
}
