package com.aiwa.controller;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.dto.request.OtpRequest;
import com.aiwa.dto.request.UpdatePreferencesRequest;
import com.aiwa.dto.request.UpdateProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.AuthService;
import com.aiwa.service.impl.OtpServiceImpl;
import com.aiwa.security.JwtUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication", description = "Register, login, OTP, token management, and profile updates")
public class AuthController {

    private static final String ACCESS_TOKEN_COOKIE = "accessToken";

    private final AuthService authService;
    private final OtpServiceImpl otpService;
    private final UserRepository userRepo;
    private final com.aiwa.repository.ProviderProfileRepository providerProfileRepo;
    private final com.aiwa.service.impl.FileStorageServiceImpl fileStorageService;
    private final JwtUtils jwtUtils;
    private final com.aiwa.repository.TermsPolicyRepository termsRepo;
    private final com.aiwa.service.impl.PushDeviceService pushDevices;

    /** DR-028: per-account budget (absent in plain unit tests). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.aiwa.service.impl.AccountRateLimiter limiter;

    /** Secure flag on the access-token cookie — on in prod (served over HTTPS). */
    @org.springframework.beans.factory.annotation.Value("${aiwa.auth.cookie-secure:false}")
    private boolean cookieSecure;

    // ── Register / Login ──────────────────────────────────────────────────────

    @PostMapping("/register")
    @Operation(summary = "Register a new user (customer or provider)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> register(
            @Valid @RequestBody AuthRequest.Register request) {
        ApiResponse.AuthResponse auth = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .header(HttpHeaders.SET_COOKIE, buildAccessTokenCookie(auth).toString())
                .body(ApiResponse.Success.of("Registration successful", auth));
    }

    @PostMapping("/login")
    @Operation(summary = "Login with email/phone + password")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> login(
            @Valid @RequestBody AuthRequest.Login request) {
        ApiResponse.AuthResponse auth = authService.login(request);
        ResponseEntity.BodyBuilder response = ResponseEntity.ok();
        if (auth.getAccessToken() != null) {
            response.header(HttpHeaders.SET_COOKIE, buildAccessTokenCookie(auth).toString());
        }
        return response.body(ApiResponse.Success.of(auth));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Refresh access token")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> refresh(
            @Valid @RequestBody AuthRequest.RefreshToken request) {
        ApiResponse.AuthResponse auth = authService.refreshToken(request.getRefreshToken());
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, buildAccessTokenCookie(auth).toString())
                .body(ApiResponse.Success.of(auth));
    }

    @PostMapping("/logout")
    @Operation(summary = "Logout and blacklist current JWT tokens")
    public ResponseEntity<ApiResponse.Success<Void>> logout(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @CookieValue(value = ACCESS_TOKEN_COOKIE, required = false) String cookieToken,
            @RequestBody(required = false) AuthRequest.Logout request) {
        // DR-030: revoke the token from wherever JwtAuthFilter would accept it —
        // the Authorization header first, else the accessToken cookie.
        String accessToken = authorization != null && authorization.startsWith("Bearer ")
                ? authorization.substring(7)
                : (cookieToken != null && !cookieToken.isBlank() ? cookieToken : null);
        authService.logout(accessToken, request != null ? request.getRefreshToken() : null);
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, clearAccessTokenCookie().toString())
                .body(ApiResponse.Success.of("Logged out successfully", null));
    }

    // ── Current user ─────────────────────────────────────────────────────────

    @GetMapping("/me")
    @Operation(summary = "Get current authenticated user profile")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> me(
            @AuthenticationPrincipal UserDetails userDetails) {
        ApiResponse.UserDto me = authService.getCurrentUser(userDetails.getUsername());
        me.setTermsUpToDate(termsUpToDate(me.getRole(), me.getAcceptedTermsVersion()));
        return ResponseEntity.ok(ApiResponse.Success.of(me));
    }

    @PatchMapping("/me")
    @Operation(summary = "Update profile — fullName, email, profileImageUrl (GAP 3)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> updateProfile(
            @Valid @RequestBody UpdateProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        user.setFullName(request.getFullName());
        if (request.getEmail() != null && !request.getEmail().isBlank()) {
            // V-01: must be a real email address (it used to accept anything,
            // including another user's phone number, which then captured that
            // person's sign-in), stored in one spelling (R2-19).
            String email;
            try {
                email = com.aiwa.util.Identifiers.normalizeEmail(request.getEmail());
            } catch (IllegalArgumentException e) {
                throw new BusinessException("auth.error.invalid_email");
            }
            if (!email.equalsIgnoreCase(user.getEmail()) && userRepo.existsByEmailIgnoreCase(email)) {
                throw new BusinessException("auth.error.email_taken");
            }
            user.setEmail(email);
        }
        String removedAvatar = null;
        if (request.getProfileImageUrl() != null) {
            String url = request.getProfileImageUrl().trim();
            // DR-013: the avatar is only ever set by POST /auth/me/avatar. Here the
            // client may resend the current value or "" to clear it. Accepting any
            // stored /files/public/ URL let a user claim someone else's image,
            // which the next avatar upload (or account deletion) then deleted.
            if (url.isEmpty()) {
                removedAvatar = user.getProfileImageUrl();
                user.setProfileImageUrl(null);
            } else if (!url.equals(user.getProfileImageUrl())) {
                throw new BusinessException("auth.error.avatar_url_not_allowed");
            }
        }
        User saved = userRepo.save(user);
        if (removedAvatar != null && removedAvatar.contains("/avatars/")) {
            fileStorageService.deletePublic(removedAvatar);
        }

        return ResponseEntity.ok(ApiResponse.Success.of("Profile updated", toUserDto(saved)));
    }

    @PostMapping(value = "/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a profile avatar image (JPEG/PNG/WebP, max 10 MB)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> uploadAvatar(
            @RequestParam("image") org.springframework.web.multipart.MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        if (limiter != null) limiter.check(user.getId(), "upload", 30, java.time.Duration.ofHours(1));
        String previous = user.getProfileImageUrl();
        String url = fileStorageService.storePublic(image, "avatars");
        user.setProfileImageUrl(url);
        User saved = userRepo.save(user);
        if (previous != null && previous.contains("/avatars/")) {
            fileStorageService.deletePublic(previous);
        }
        return ResponseEntity.ok(ApiResponse.Success.of("Avatar updated", toUserDto(saved)));
    }

    @PatchMapping("/me/phone")
    @Operation(summary = "Change your phone number — send-otp to the NEW number first, then call this with the code. "
            + "Returns a fresh token pair; other sessions are signed out.")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> changePhone(
            @Valid @RequestBody AuthRequest.ChangePhone request,
            @AuthenticationPrincipal UserDetails userDetails) {
        ApiResponse.AuthResponse auth = authService.changePhone(userDetails.getUsername(), request);
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, buildAccessTokenCookie(auth).toString())
                .body(ApiResponse.Success.of("Phone number updated", auth));
    }

    @PatchMapping("/me/language")
    @Operation(summary = "Update preferred language (EN or AR)")
    public ResponseEntity<ApiResponse.Success<Void>> updateLanguage(
            @Valid @RequestBody AuthRequest.UpdateLanguage request,
            @AuthenticationPrincipal UserDetails userDetails) {
        authService.updateLanguage(userDetails.getUsername(), request.getPreferredLanguage());
        return ResponseEntity.ok(ApiResponse.Success.of("Language preference updated", null));
    }

    @PatchMapping("/me/preferences")
    @Operation(summary = "Update search preferences — radius and \"Your area\" (label + coordinates, or clearSearchArea=true)")
    public ResponseEntity<ApiResponse.Success<Void>> updatePreferences(
            @Valid @RequestBody UpdatePreferencesRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        if (request.getSearchRadiusMinKm() != null)
            user.setSearchRadiusMinKm(request.getSearchRadiusMinKm());
        if (request.getSearchRadiusMaxKm() != null)
            user.setSearchRadiusMaxKm(request.getSearchRadiusMaxKm());
        if (user.getSearchRadiusMinKm() != null && user.getSearchRadiusMaxKm() != null
                && user.getSearchRadiusMinKm() > user.getSearchRadiusMaxKm()) {
            throw new BusinessException("auth.error.radius_min_above_max");
        }
        if (Boolean.TRUE.equals(request.getClearSearchArea())) {
            user.setSearchAreaLabel(null);
            user.setSearchAreaLatitude(null);
            user.setSearchAreaLongitude(null);
        } else if (request.getSearchAreaLabel() != null || request.getSearchAreaLatitude() != null) {
            if ((request.getSearchAreaLatitude() == null) != (request.getSearchAreaLongitude() == null)) {
                throw new BusinessException("auth.error.search_area_coordinates");
            }
            user.setSearchAreaLabel(request.getSearchAreaLabel());
            user.setSearchAreaLatitude(request.getSearchAreaLatitude());
            user.setSearchAreaLongitude(request.getSearchAreaLongitude());
        }
        userRepo.save(user);

        return ResponseEntity.ok(ApiResponse.Success.of("Preferences saved", null));
    }

    @GetMapping("/me/notification-preferences")
    @Operation(summary = "Get notification preferences (channels + quiet hours)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationPreferencesDto>> getNotificationPreferences(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(toPrefsDto(resolveUser(userDetails))));
    }

    @PatchMapping("/me/notification-preferences")
    @Operation(summary = "Update notification preferences (channels + quiet hours)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationPreferencesDto>> updateNotificationPreferences(
            @Valid @RequestBody com.aiwa.dto.request.UpdateNotificationPreferencesRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        if (request.getNotifyPush()  != null) user.setNotifyPush(request.getNotifyPush());
        if (request.getNotifyEmail() != null) user.setNotifyEmail(request.getNotifyEmail());
        if (request.getNotifySms()   != null) user.setNotifySms(request.getNotifySms());
        if (request.getNotifyWhatsapp() != null) user.setNotifyWhatsapp(request.getNotifyWhatsapp());
        if (request.getMuteAll()     != null) user.setMuteAll(request.getMuteAll());
        if (Boolean.TRUE.equals(request.getClearQuietHours())) {
            user.setQuietHoursStart(null);
            user.setQuietHoursEnd(null);
        } else {
            if (request.getQuietHoursStart() != null) user.setQuietHoursStart(request.getQuietHoursStart());
            if (request.getQuietHoursEnd()   != null) user.setQuietHoursEnd(request.getQuietHoursEnd());
        }
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of("Notification preferences updated", toPrefsDto(user)));
    }

    private ApiResponse.NotificationPreferencesDto toPrefsDto(User u) {
        return ApiResponse.NotificationPreferencesDto.builder()
                .notifyPush(u.isNotifyPush())
                .notifyEmail(u.isNotifyEmail())
                .notifySms(u.isNotifySms())
                .notifyWhatsapp(u.isNotifyWhatsapp())
                .muteAll(u.isMuteAll())
                .quietHoursStart(u.getQuietHoursStart())
                .quietHoursEnd(u.getQuietHoursEnd())
                .build();
    }

    // ── Push device registration ─────────────────────────────────────────────
    // The missing piece push delivery needed: somewhere to store *this device's*
    // address. The mobile app calls this once it has an FCM/APNs registration id
    // (on login, and again whenever the OS hands it a refreshed token).

    @PatchMapping("/me/push-token")
    @Operation(summary = "Register this device's push token (call on login and whenever the OS refreshes it)")
    public ResponseEntity<ApiResponse.Success<Void>> updatePushToken(
            @Valid @RequestBody com.aiwa.dto.request.UpdatePushTokenRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        pushDevices.register(user, request.getToken(), request.getPlatform());
        return ResponseEntity.ok(ApiResponse.Success.of("Push token registered", null));
    }

    @DeleteMapping("/me/push-token")
    @Operation(summary = "Stop pushes to this device (?token=…), or to all of your devices when no token is given "
            + "(call on logout / when push is disabled)")
    public ResponseEntity<ApiResponse.Success<Void>> clearPushToken(
            @RequestParam(value = "token", required = false) String token,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        pushDevices.unregister(user, token);
        return ResponseEntity.ok(ApiResponse.Success.of("Push token cleared", null));
    }

    // ── OTP endpoints (GAP 1) ────────────────────────────────────────────────

    @PostMapping("/send-otp")
    @Operation(summary = "Send a 6-digit OTP by SMS ({phone}) or by email ({email}). "
            + "Limited per destination (3 per 10 min, 10 per day) — 429 when exceeded.")
    public ResponseEntity<ApiResponse.Success<Void>> sendOtp(
            @Valid @RequestBody OtpRequest.SendOtp request) {
        if (request.getPhone() != null && !request.getPhone().isBlank()) {
            otpService.sendOtp(request.getPhone().trim());
            return ResponseEntity.ok(ApiResponse.Success.of(
                    "Code sent to " + request.getPhone() + ". Valid for 10 minutes.", null));
        }
        otpService.sendEmailOtp(request.getEmail());
        return ResponseEntity.ok(ApiResponse.Success.of(
                "Code sent to " + request.getEmail() + ". Valid for 10 minutes.", null));
    }

    @PostMapping("/verify-otp")
    @Operation(summary = "Verify OTP ({phone} or {email} + code) — call before /register to confirm ownership")
    public ResponseEntity<ApiResponse.Success<Void>> verifyOtp(
            @Valid @RequestBody OtpRequest.VerifyOtp request) {
        if (request.getPhone() != null && !request.getPhone().isBlank()) {
            otpService.verifyOtp(request.getPhone().trim(), request.getCode());
            return ResponseEntity.ok(ApiResponse.Success.of("Phone verified successfully", null));
        }
        otpService.verifyEmailOtp(request.getEmail(), request.getCode());
        return ResponseEntity.ok(ApiResponse.Success.of("Email verified successfully", null));
    }

    @PostMapping("/reset-password")
    @Operation(summary = "Forgot password — reset with phone or email + OTP code + new password "
            + "(signs out every existing session)")
    public ResponseEntity<ApiResponse.Success<Void>> resetPassword(
            @Valid @RequestBody AuthRequest.ResetPassword request) {
        authService.resetPassword(request);
        return ResponseEntity.ok(ApiResponse.Success.of("Password reset successfully. You can now sign in.", null));
    }

    // ── Two-factor authentication (TOTP) ─────────────────────────────────────
    // /2fa/verify is deliberately public (no session exists yet at this point in
    // the login flow) — it's gated instead by the short-lived, purpose-scoped
    // mfaToken from /auth/login. The rest require a normal authenticated session.

    @PostMapping("/2fa/verify")
    @Operation(summary = "Step 2 of login when the account has 2FA enabled — exchange mfaToken + code for a real session")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> verifyMfa(
            @Valid @RequestBody AuthRequest.VerifyMfa request) {
        ApiResponse.AuthResponse auth = authService.verifyMfa(request.getMfaToken(), request.getCode());
        return ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, buildAccessTokenCookie(auth).toString())
                .body(ApiResponse.Success.of(auth));
    }

    private ResponseCookie buildAccessTokenCookie(ApiResponse.AuthResponse auth) {
        long maxAgeSeconds = Math.max(1, jwtUtils.getRemainingValidityMillis(auth.getAccessToken()) / 1000);
        return ResponseCookie.from(ACCESS_TOKEN_COOKIE, auth.getAccessToken())
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite("Lax")
                .path("/")
                .maxAge(maxAgeSeconds)
                .build();
    }

    private ResponseCookie clearAccessTokenCookie() {
        return ResponseCookie.from(ACCESS_TOKEN_COOKIE, "")
                .httpOnly(true)
                .secure(cookieSecure)
                .sameSite("Lax")
                .path("/")
                .maxAge(0)
                .build();
    }

    /**
     * Server clock exposed publicly so a user whose authenticator codes keep
     * getting rejected can compare their phone's time to ours — a mismatch of
     * more than the drift tolerance (taken from TotpService, 30s) is the single
     * most common cause of "TOTP not working".
     * No auth required; returns nothing but the current server time.
     */
    @GetMapping("/2fa/server-time")
    @Operation(summary = "Server clock — compare against your phone's time when TOTP codes are being rejected")
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> serverTime() {
        long millis = System.currentTimeMillis();
        return ResponseEntity.ok(ApiResponse.Success.of(java.util.Map.of(
                "epochMillis", millis,
                "iso", java.time.Instant.ofEpochMilli(millis).toString(),
                "totpStepSeconds", com.aiwa.security.TotpService.stepSeconds(),
                "driftToleranceSeconds", com.aiwa.security.TotpService.driftToleranceSeconds()
        )));
    }

    @PostMapping("/2fa/setup")
    @Operation(summary = "Start (or restart) 2FA setup — returns a secret to add to an authenticator app. "
            + "Needs the current password, and the current code when 2FA is already on.")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TwoFactorSetupDto>> setupTotp(
            @Valid @RequestBody AuthRequest.ConfirmIdentity request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                authService.beginTotpSetup(userDetails.getUsername(), request.getPassword(), request.getCode())));
    }

    @PostMapping("/2fa/enable")
    @Operation(summary = "Confirm 2FA setup with a code from the authenticator app")
    public ResponseEntity<ApiResponse.Success<Void>> enableTotp(
            @Valid @RequestBody AuthRequest.EnableTotp request,
            @AuthenticationPrincipal UserDetails userDetails) {
        authService.enableTotp(userDetails.getUsername(), request.getCode());
        return ResponseEntity.ok(ApiResponse.Success.of("Two-factor authentication enabled", null));
    }

    @PostMapping("/2fa/disable")
    @Operation(summary = "Turn off 2FA for this account (current password + current code)")
    public ResponseEntity<ApiResponse.Success<Void>> disableTotp(
            @Valid @RequestBody AuthRequest.ConfirmIdentity request,
            @AuthenticationPrincipal UserDetails userDetails) {
        authService.disableTotp(userDetails.getUsername(), request.getPassword(), request.getCode());
        return ResponseEntity.ok(ApiResponse.Success.of("Two-factor authentication disabled", null));
    }

    @GetMapping("/2fa/status")
    @Operation(summary = "Whether 2FA is currently enabled for this account")
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, Boolean>>> totpStatus(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                java.util.Map.of("enabled", authService.isTotpEnabled(userDetails.getUsername()))));
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private User resolveUser(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        return (id != null ? userRepo.findById(id) : userRepo.findByLogin(ud.getUsername()))
                .orElseThrow(() -> new BusinessException("user.not_found"));
    }

    /** Accepted version vs. the live policy for the user's role (admins: always current). */
    private boolean termsUpToDate(com.aiwa.enums.UserRole role, String acceptedVersion) {
        if (role == com.aiwa.enums.UserRole.ADMIN) return true;
        String type = role == com.aiwa.enums.UserRole.PROVIDER ? "PROVIDER_TERMS" : "CUSTOMER_TERMS";
        return termsRepo.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc(type)
                .map(live -> live.getVersion().equals(acceptedVersion))
                .orElse(true);
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
                .termsUpToDate(termsUpToDate(u.getRole(), u.getAcceptedTermsVersion()))
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
