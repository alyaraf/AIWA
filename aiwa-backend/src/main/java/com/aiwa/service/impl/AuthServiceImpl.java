package com.aiwa.service.impl;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.InvalidTokenException;
import com.aiwa.exception.TooManyRequestsException;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
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
public class AuthServiceImpl {

    private final UserRepository userRepository;
    private final com.aiwa.repository.ProviderProfileRepository providerProfileRepo;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtUtils jwtUtils;
    private final OtpServiceImpl otpService;
    private final TokenBlacklistService tokenBlacklistService;
    private final TotpService totpService;

    // CR-01 limits. Not constructor arguments: the numbers come from
    // application.yml (aiwa.auth.*) and default to the same values.
    /** Sign-in attempts (password or 2FA code) an account gets before it is locked. */
    @org.springframework.beans.factory.annotation.Value("${aiwa.auth.max-failed-attempts:5}")
    private int maxFailedAttempts = 5;
    /** How long a locked account refuses sign-in. */
    @org.springframework.beans.factory.annotation.Value("${aiwa.auth.lockout-duration:15m}")
    private java.time.Duration lockoutDuration = java.time.Duration.ofMinutes(15);
    /** Wrong codes one MFA challenge survives; the next sign-in needs the password again. */
    @org.springframework.beans.factory.annotation.Value("${aiwa.auth.mfa-max-wrong-codes:5}")
    private int mfaMaxWrongCodes = 5;
    /** Only counts wrong codes per MFA challenge; the per-account count is in the database. */
    @org.springframework.beans.factory.annotation.Autowired
    private RedisRuntimeService redis;

    @Transactional
    public ApiResponse.AuthResponse register(AuthRequest.Register req) {
        // One spelling per email and phone (R2-19): "Nour@x.com" and "nour@x.com",
        // or 010… and +2010…, used to become two separate accounts.
        String email = email(req.getEmail());
        String phone = Identifiers.normalizePhone(req.getPhone());
        requirePasswordFitsBcrypt(req.getPassword());
        if (email == null && phone == null) {
            throw new BusinessException("auth.error.email_or_phone_required");
        }
        if (req.getRole() == UserRole.ADMIN) {
            throw new BusinessException("auth.error.admin_registration_blocked");
        }
        // AU-14 / L-1: ownership is proved before "already taken" is answered, so the
        // register endpoint can't be used to find out which numbers have an account.
        if (phone != null && !otpService.isPhoneVerified(phone, req.getVerificationReceipt())) {
            throw new BusinessException("auth.error.phone_not_verified");
        }
        // An email-only account must prove it owns the address (email OTP, BE-10);
        // before, any unverified address could be registered.
        if (phone == null && !otpService.isEmailVerified(email, req.getVerificationReceipt())) {
            throw new BusinessException("auth.error.email_not_verified");
        }
        if (email != null && userRepository.existsByEmailIgnoreCase(email)) {
            throw new BusinessException("auth.error.email_taken");
        }
        if (phone != null && userRepository.existsByPhone(phone)) {
            throw new BusinessException("auth.error.phone_taken");
        }

        // CR-05: only an address proved with a code becomes the account's email.
        // A phone sign-up proved the phone, not the email, so that one waits.
        boolean emailProved = phone == null;

        User user = User.builder()
                .fullName(req.getFullName().trim())
                .email(emailProved ? email : null)
                .pendingEmail(emailProved ? null : email)
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
        if (emailProved) {
            otpService.consumeEmailVerification(email);
        } else if (email != null) {
            try {
                otpService.sendEmailOtp(email);
            } catch (RuntimeException e) {
                // The sign-up stands (the phone is proved). PATCH /auth/me with the
                // same email sends the code again.
            }
        }

        return buildAuthResponse(user);
    }

    public ApiResponse.AuthResponse login(AuthRequest.Login req) {
        // CR-01: the attempt is taken from the account's budget before the password
        // is looked at, so parallel guesses cannot outrun the count.
        User user = userRepository.findByLogin(req.getIdentifier()).orElse(null);
        if (user != null) claimSignInAttempt(user);

        // Throws for an unknown account or a wrong password: the attempt stays spent.
        Authentication auth = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.getIdentifier(), req.getPassword())
        );
        if (user == null) throw new BadCredentialsException("Invalid credentials");

        if (user.isTotpEnabled()) {
            // The password was right, so this attempt is given back, but the count is
            // not cleared: only a completed sign-in does that. Otherwise someone who
            // knows the password could reset the 2FA guess count by signing in again.
            userRepository.releaseLoginAttempt(user.getId());
            // Password checked out, but the account requires a second factor.
            // No access/refresh token is issued yet — only a short-lived,
            // purpose-scoped challenge token that /auth/2fa/verify will exchange
            // for a real session once the TOTP code checks out.
            return ApiResponse.AuthResponse.builder()
                    .mfaRequired(true)
                    .mfaToken(jwtUtils.generateMfaChallengeToken(identifierOf(user), user.getId()))
                    .build();
        }

        userRepository.clearLoginAttempts(user.getId());
        return buildAuthResponse(user);
    }

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

        // CR-01: a code guess counts against the account like a password guess…
        claimSignInAttempt(user);
        if (!user.isTotpEnabled() || !acceptTotp(user, code)) {
            // …and against this challenge.
            countWrongCode(mfaToken);
            throw new BusinessException("auth.error.invalid_totp_code");
        }

        // The challenge is single-use and spent atomically: of two parallel
        // verifies with the same token only one gets a session (DR-017).
        if (!tokenBlacklistService.claimStrict(mfaToken)) {
            throw new InvalidTokenException("auth.error.token_invalid");
        }
        userRepository.clearLoginAttempts(user.getId());
        return buildAuthResponse(user);
    }

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
        user.setTotpLastUsedStep(null); // new secret: none of its codes has been used
        user.setTotpEnabled(false);
        userRepository.save(user);

        String label = identifierOf(user);
        return ApiResponse.TwoFactorSetupDto.builder()
                .secret(secret)
                .otpAuthUri(totpService.buildOtpAuthUri(secret, label, "AIWA"))
                .build();
    }

    /**
     * SA-02: turning two-factor on ends every session issued before it, refresh tokens
     * included, because those were minted without a code. The caller gets a fresh pair.
     */
    @Transactional
    public ApiResponse.AuthResponse enableTotp(String identifier, String code) {
        User user = findUser(identifier);

        if (user.getTotpSecret() == null) {
            throw new BusinessException("auth.error.totp_setup_not_started");
        }
        if (!acceptTotp(user, code)) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }
        user.setTotpEnabled(true);
        user.setTokensValidAfter(sessionCutoff());
        userRepository.save(user);
        return buildAuthResponse(user);
    }

    @Transactional
    public void disableTotp(String identifier, String password, String code) {
        User user = findUser(identifier);
        requireReauthentication(user, password, code);
        user.setTotpEnabled(false);
        user.setTotpSecret(null);
        userRepository.save(user);
    }

    public boolean isTotpEnabled(String identifier) {
        return findUser(identifier).isTotpEnabled();
    }

    /**
     * Exchange a refresh token for a new pair. Only a real refresh token is
     * accepted (not an access or MFA token), tokens issued before the account's
     * session cut-off are refused, and the used refresh token is revoked
     * (rotation) so a stolen copy can't keep minting sessions in parallel.
     */
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

    public void logout(String accessToken, String refreshToken) {
        tokenBlacklistService.blacklist(accessToken);
        tokenBlacklistService.blacklist(refreshToken);
    }

    public ApiResponse.UserDto getCurrentUser(String identifier) {
        return toUserDto(findUser(identifier));
    }

    /**
     * Forgot password, by phone or email. Every session issued before the reset
     * is revoked — someone who reset because their password leaked must not stay
     * signed in on the attacker's device.
     */
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
        userRepository.clearLoginAttempts(user.getId()); // the owner proved themselves by OTP: lift a sign-in lock
        if (phone != null) otpService.consumePhoneVerification(phone);
        else otpService.consumeEmailVerification(email);
    }

    /**
     * Change the account phone (BE-19). The new number must pass OTP first. Old
     * sessions are revoked — a phone-based login's token subject is the old
     * number — and a fresh token pair for the new identity is returned.
     */
    @Transactional
    public ApiResponse.AuthResponse changePhone(String identifier, AuthRequest.ChangePhone req) {
        User user = findUser(identifier);
        // CR-05: before the code is looked at, so a refused request does not spend it.
        requireCurrentPassword(user, req.getCurrentPassword());
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
        user.setTokensValidAfter(sessionCutoff());
        userRepository.save(user);
        return buildAuthResponse(user);
    }

    public void confirmPassword(String identifier, String password) {
        requireCurrentPassword(findUser(identifier), password);
    }

    /**
     * CR-05: the address waiting in pendingEmail becomes the account's email once
     * the code sent to it checks out. Like a phone change, every other session is
     * ended and the caller gets a fresh token pair.
     */
    @Transactional
    public ApiResponse.AuthResponse confirmEmail(String identifier, String code) {
        User user = findUser(identifier);
        String email = user.getPendingEmail();
        if (email == null) throw new BusinessException("auth.error.no_pending_email");
        otpService.verifyEmailOtp(email, code);
        otpService.consumeEmailVerification(email);
        // Someone else may have registered the address while it waited here.
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new BusinessException("auth.error.email_taken");
        }
        user.setEmail(email);
        user.setPendingEmail(null);
        user.setTokensValidAfter(sessionCutoff());
        userRepository.save(user);
        return buildAuthResponse(user);
    }

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

    /**
     * Current password, plus the current authenticator code when 2FA is on (DR-017).
     * Guesses here count against the account like sign-in guesses (CR-01), so a
     * stolen session cannot be used to try passwords or codes without limit.
     */
    private void requireReauthentication(User user, String password, String code) {
        requirePasswordGuess(user, password);
        if (user.isTotpEnabled() && (code == null || !acceptTotp(user, code))) {
            throw new BusinessException("auth.error.invalid_totp_code");
        }
        userRepository.clearLoginAttempts(user.getId());
    }

    /**
     * Session cut-off for a change that hands the caller new tokens straight away.
     * Whole milliseconds, because tokens carry their issue time in milliseconds: with
     * the microseconds kept, the new tokens (issued in the same millisecond) were
     * refused as older than the cut-off.
     */
    private static Instant sessionCutoff() {
        return Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MILLIS);
    }

    /** CR-05: the current password alone, for email change, phone change and account deletion. */
    private void requireCurrentPassword(User user, String password) {
        requirePasswordGuess(user, password);
        userRepository.clearLoginAttempts(user.getId());
    }

    /** One counted guess at the current password (CR-01): a missing or wrong one is refused. */
    private void requirePasswordGuess(User user, String password) {
        claimSignInAttempt(user);
        if (password == null || !passwordEncoder.matches(password, user.getPassword())) {
            throw new BusinessException("auth.error.wrong_password");
        }
    }

    /** CR-01: takes one of the account's sign-in attempts, or answers 429 while the account is locked. */
    private void claimSignInAttempt(User user) {
        Instant now = Instant.now();
        if (userRepository.claimLoginAttempt(user.getId(), maxFailedAttempts, now, now.minus(lockoutDuration)) == 0) {
            throw new TooManyRequestsException("auth.error.too_many_attempts");
        }
    }

    /**
     * CR-01: a code is accepted once. It must match, and its time step must be
     * newer than the last one this account used, so a code that was just used
     * (seen over a shoulder, replayed from a proxy) is refused inside its window.
     */
    private boolean acceptTotp(User user, String code) {
        Long step = totpService.matchingStep(user.getTotpSecret(), code);
        if (step == null || userRepository.claimTotpStep(user.getId(), step) == 0) return false;
        user.setTotpLastUsedStep(step); // keep the loaded entity in step: a later save(user) writes this column
        return true;
    }

    /** CR-01: a wrong code uses up one of the challenge's attempts; after the last one the challenge is spent. */
    private void countWrongCode(String mfaToken) {
        long wrong;
        try {
            wrong = redis.increment("mfa:wrong:" + TokenBlacklistService.hash(mfaToken),
                    java.time.Duration.ofMillis(Math.max(1000, jwtUtils.getRemainingValidityMillis(mfaToken))));
        } catch (RuntimeException e) {
            // Redis down: the wrong codes cannot be counted, so the first one ends the
            // challenge (never more than the cap). The per-account count is unaffected.
            wrong = mfaMaxWrongCodes;
        }
        if (wrong >= mfaMaxWrongCodes) tokenBlacklistService.claimStrict(mfaToken);
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
        String refresh = user.getRole() == UserRole.ADMIN
                ? jwtUtils.generateRefreshToken(identifier, user.getId(), true) // L-18: shorter for admins
                : jwtUtils.generateRefreshToken(identifier, user.getId());

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
                .pendingEmail(u.getPendingEmail())
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
