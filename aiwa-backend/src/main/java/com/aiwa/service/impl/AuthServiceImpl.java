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
import com.aiwa.util.Identifiers;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.*;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

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
        // One spelling per email and phone (R2-19): "Nour@x.com" and "nour@x.com",
        // or 010… and +2010…, used to become two separate accounts.
        String email = email(req.getEmail());
        String phone = Identifiers.normalizePhone(req.getPhone());
        requirePasswordFitsBcrypt(req.getPassword());
        if (email != null && userRepository.existsByEmailIgnoreCase(email)) {
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

        return buildAuthResponse(user);
    }

    @Override
    public ApiResponse.AuthResponse login(AuthRequest.Login req) {
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.getIdentifier(), req.getPassword())
        );

        User user = userRepository.findByLogin(req.getIdentifier())
                .orElseThrow(() -> new BadCredentialsException("Invalid credentials"));

        if (user.isTotpEnabled()) {
            // Password checked out, but the account requires a second factor.
            // No access/refresh token is issued yet — only a short-lived,
            // purpose-scoped challenge token that /auth/2fa/verify will exchange
            // for a real session once the TOTP code checks out.
            return ApiResponse.AuthResponse.builder()
                    .mfaRequired(true)
                    .mfaToken(jwtUtils.generateMfaChallengeToken(identifierOf(user), user.getId()))
                    .build();
        }

        return buildAuthResponse(user);
    }

    @Override
    public ApiResponse.AuthResponse verifyMfa(String mfaToken, String code) {
        if (mfaToken == null || !jwtUtils.isMfaChallengeToken(mfaToken) || !jwtUtils.validateToken(mfaToken)
                || tokenBlacklistService.isBlacklistedStrict(mfaToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        User user = userOf(mfaToken);
        if (!user.isActive()) {
            throw new InvalidTokenException("auth.error.account_disabled");
        }
        // DR-017: a challenge issued before a password reset or suspension is dead.
        requireIssuedAfterCutoff(user, mfaToken);

        if (!user.isTotpEnabled() || !totpService.verifyCode(user.getTotpSecret(), code)) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }

        // The challenge is single-use and spent atomically: of two parallel
        // verifies with the same token only one gets a session (DR-017).
        if (!tokenBlacklistService.claimStrict(mfaToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        return buildAuthResponse(user);
    }

    @Override
    public ApiResponse.TwoFactorSetupDto beginTotpSetup(String identifier, String password, String code) {
        User user = findUser(identifier);
        // DR-017: restarting setup replaces the secret and turns 2FA off until the
        // new one is confirmed, so a signed-in session alone is not enough.
        requireReauthentication(user, password, code);

        // A fresh secret every time setup is (re)started — it only becomes
        // trusted for login once enableTotp() confirms the user can actually
        // produce a matching code with it.
        String secret = totpService.generateSecret();
        user.setTotpSecret(secret);
        user.setTotpEnabled(false);
        userRepository.save(user);

        String label = identifierOf(user);
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
    public void disableTotp(String identifier, String password, String code) {
        User user = findUser(identifier);
        requireReauthentication(user, password, code);
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
        if (!jwtUtils.validateToken(refreshToken) || !jwtUtils.isRefreshToken(refreshToken)
                || tokenBlacklistService.isBlacklistedStrict(refreshToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        User user = userOf(refreshToken);

        // A deactivated/suspended account must not be able to mint fresh access
        // tokens from a still-valid refresh token.
        if (!user.isActive()) {
            throw new InvalidTokenException("auth.error.account_disabled");
        }
        requireIssuedAfterCutoff(user, refreshToken);

        // Spend the token atomically before minting new ones: of two parallel
        // refreshes with the same token only one gets a new pair (BE-42). With
        // Redis down this now answers 503 instead of letting a spent or
        // logged-out refresh token mint sessions (DR-002).
        if (!tokenBlacklistService.claimStrict(refreshToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        return buildAuthResponse(user);
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
        requirePasswordFitsBcrypt(req.getNewPassword());
        String phone = Identifiers.normalizePhone(req.getPhone());
        String email = null;
        if (phone != null) {
            // Verifies the OTP (throws if invalid/expired) then sets the new password.
            otpService.verifyOtp(phone, req.getCode());
            user = userRepository.findByPhone(phone)
                    .orElseThrow(() -> new BusinessException("auth.error.phone_not_found"));
        } else {
            email = email(req.getEmail());
            if (email == null) throw new BusinessException("auth.error.email_or_phone_required");
            otpService.verifyEmailOtp(email, req.getCode());
            user = userRepository.findByEmailIgnoreCase(email)
                    .orElseThrow(() -> new BusinessException("auth.error.email_not_found"));
        }

        user.setPassword(passwordEncoder.encode(req.getNewPassword()));
        user.setTokensValidAfter(Instant.now());
        userRepository.save(user);
        if (phone != null) otpService.consumePhoneVerification(phone);
        else otpService.consumeEmailVerification(email);
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
        String phone = Identifiers.normalizePhone(req.getPhone());
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
        return buildAuthResponse(user);
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
        return userRepository.findByLogin(identifier)
                .orElseThrow(() -> new BusinessException("user.not_found"));
    }

    /** The account a refresh or MFA token belongs to: by its userId claim, never by guessing from the subject (V-01). */
    private User userOf(String token) {
        Long userId = jwtUtils.getUserIdFromToken(token);
        java.util.Optional<User> user = userId != null
                ? userRepository.findById(userId)
                : userRepository.findByLogin(jwtUtils.getSubjectFromToken(token)); // tokens from before the claim
        return user.orElseThrow(() -> new InvalidTokenException("auth.error.token_invalid"));
    }

    /** Tokens issued before the account's session cut-off (reset, suspension, phone change) are refused. */
    private void requireIssuedAfterCutoff(User user, String token) {
        if (user.getTokensValidAfter() == null) return;
        Instant issued = jwtUtils.getIssuedAt(token);
        if (issued == null || issued.isBefore(user.getTokensValidAfter())) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
    }

    /** Current password, plus the current authenticator code when 2FA is on (DR-017). */
    private void requireReauthentication(User user, String password, String code) {
        if (password == null || !passwordEncoder.matches(password, user.getPassword())) {
            throw new BusinessException("auth.error.wrong_password");
        }
        if (user.isTotpEnabled() && (code == null || !totpService.verifyCode(user.getTotpSecret(), code))) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }
    }

    /** BCrypt reads only the first 72 bytes; a longer password would accept anything sharing that prefix. */
    private static void requirePasswordFitsBcrypt(String password) {
        if (password != null && password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) {
            throw new BusinessException("auth.error.password_too_long");
        }
    }

    private static String email(String raw) {
        try {
            return Identifiers.normalizeEmail(raw);
        } catch (IllegalArgumentException e) {
            throw new BusinessException("auth.error.invalid_email");
        }
    }

    private static String identifierOf(User user) {
        return user.getEmail() != null ? user.getEmail() : user.getPhone();
    }

    private ApiResponse.AuthResponse buildAuthResponse(User user) {
        String identifier = identifierOf(user);
        String access  = jwtUtils.generateAccessToken(identifier, user.getId(), user.getRole().name());
        String refresh = jwtUtils.generateRefreshToken(identifier, user.getId());

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
