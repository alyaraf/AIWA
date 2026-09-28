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
            @RequestBody(required = false) AuthRequest.Logout request) {
        String accessToken = authorization != null && authorization.startsWith("Bearer ")
                ? authorization.substring(7)
                : null;
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
        return ResponseEntity.ok(
                ApiResponse.Success.of(authService.getCurrentUser(userDetails.getUsername())));
    }

    @PatchMapping("/me")
    @Operation(summary = "Update profile — fullName, email, profileImageUrl (GAP 3)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> updateProfile(
            @Valid @RequestBody UpdateProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        user.setFullName(request.getFullName());
        if (request.getEmail() != null && !request.getEmail().isBlank()) {
            if (!request.getEmail().equals(user.getEmail())
                    && userRepo.existsByEmail(request.getEmail())) {
                throw new BusinessException("auth.error.email_taken");
            }
            user.setEmail(request.getEmail());
        }
        if (request.getProfileImageUrl() != null) {
            user.setProfileImageUrl(request.getProfileImageUrl());
        }
        User saved = userRepo.save(user);

        return ResponseEntity.ok(ApiResponse.Success.of("Profile updated", toUserDto(saved)));
    }

    @PostMapping(value = "/me/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload a profile avatar image")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> uploadAvatar(
            @RequestParam("image") org.springframework.web.multipart.MultipartFile image,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        String path = fileStorageService.storePublic(image);
        user.setProfileImageUrl(path);
        return ResponseEntity.ok(ApiResponse.Success.of("Avatar updated", toUserDto(userRepo.save(user))));
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
    @Operation(summary = "Update search radius preferences (GAP 4)")
    public ResponseEntity<ApiResponse.Success<Void>> updatePreferences(
            @Valid @RequestBody UpdatePreferencesRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        User user = resolveUser(userDetails);
        if (request.getSearchRadiusMinKm() != null)
            user.setSearchRadiusMinKm(request.getSearchRadiusMinKm());
        if (request.getSearchRadiusMaxKm() != null)
            user.setSearchRadiusMaxKm(request.getSearchRadiusMaxKm());
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
        user.setPushToken(request.getToken());
        user.setPushPlatform(request.getPlatform());
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of("Push token registered", null));
    }

    @DeleteMapping("/me/push-token")
    @Operation(summary = "Clear this device's push token (call on logout / when push is disabled)")
    public ResponseEntity<ApiResponse.Success<Void>> clearPushToken(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        user.setPushToken(null);
        user.setPushPlatform(null);
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of("Push token cleared", null));
    }

    // ── OTP endpoints (GAP 1) ────────────────────────────────────────────────

    @PostMapping("/send-otp")
    @Operation(summary = "Send a 6-digit OTP to a phone number")
    public ResponseEntity<ApiResponse.Success<Void>> sendOtp(
            @Valid @RequestBody OtpRequest.SendOtp request) {
        otpService.sendOtp(request.getPhone());
        return ResponseEntity.ok(ApiResponse.Success.of(
                "Code sent to " + request.getPhone() + ". Valid for 10 minutes.", null));
    }

    @PostMapping("/verify-otp")
    @Operation(summary = "Verify OTP — call before /register to confirm phone ownership")
    public ResponseEntity<ApiResponse.Success<Void>> verifyOtp(
            @Valid @RequestBody OtpRequest.VerifyOtp request) {
        otpService.verifyOtp(request.getPhone(), request.getCode());
        return ResponseEntity.ok(ApiResponse.Success.of("Phone verified successfully", null));
    }

    @PostMapping("/reset-password")
    @Operation(summary = "Forgot password — reset with phone + OTP code + new password")
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
                .secure(false)
                .sameSite("Lax")
                .path("/")
                .maxAge(maxAgeSeconds)
                .build();
    }

    private ResponseCookie clearAccessTokenCookie() {
        return ResponseCookie.from(ACCESS_TOKEN_COOKIE, "")
                .httpOnly(true)
                .secure(false)
                .sameSite("Lax")
                .path("/")
                .maxAge(0)
                .build();
    }

    /**
     * Server clock exposed publicly so a user whose authenticator codes keep
     * getting rejected can compare their phone's time to ours — a mismatch of
     * more than ~90s is the single most common cause of "TOTP not working".
     * No auth required; returns nothing but the current server time.
     */
    @GetMapping("/2fa/server-time")
    @Operation(summary = "Server clock — compare against your phone's time when TOTP codes are being rejected")
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> serverTime() {
        long millis = System.currentTimeMillis();
        return ResponseEntity.ok(ApiResponse.Success.of(java.util.Map.of(
                "epochMillis", millis,
                "iso", java.time.Instant.ofEpochMilli(millis).toString(),
                "totpStepSeconds", 30,
                "driftToleranceSeconds", 90
        )));
    }

    @PostMapping("/2fa/setup")
    @Operation(summary = "Start (or restart) 2FA setup — returns a secret to add to an authenticator app")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TwoFactorSetupDto>> setupTotp(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                authService.beginTotpSetup(userDetails.getUsername())));
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
    @Operation(summary = "Turn off 2FA for this account")
    public ResponseEntity<ApiResponse.Success<Void>> disableTotp(
            @AuthenticationPrincipal UserDetails userDetails) {
        authService.disableTotp(userDetails.getUsername());
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
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow(() -> new BusinessException("user.not_found"));
    }

    private ApiResponse.UserDto toUserDto(User u) {
        // Lets the app gate unapproved providers on the pending screen.
        var provider = u.getRole() == com.aiwa.enums.UserRole.PROVIDER
                ? providerProfileRepo.findByUserId(u.getId()).orElse(null) : null;
        return ApiResponse.UserDto.builder()
                .providerProfileId(provider == null ? null : provider.getId())
                .providerStatus(provider == null ? null : provider.getVerificationStatus())
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
