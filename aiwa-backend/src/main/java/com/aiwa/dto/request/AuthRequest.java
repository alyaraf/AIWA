package com.aiwa.dto.request;

import com.aiwa.enums.Gender;
import com.aiwa.enums.Language;
import com.aiwa.enums.UserRole;
import jakarta.validation.constraints.*;
import lombok.Data;

public class AuthRequest {

    @Data
    public static class Register {
        @NotBlank(message = "Full name is required")
        @Size(max = 120, message = "Full name must be at most 120 characters")
        private String fullName;

        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;

        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;

        /** BCrypt only uses the first 72 bytes, so longer passwords are refused rather than silently cut. */
        @NotBlank(message = "Password is required")
        @Size(min = 6, max = 72, message = "Password must be 6–72 characters")
        private String password;

        @NotNull(message = "Role is required")
        private UserRole role;

        private Gender gender;

        /** Gap 6: language preference set at registration */
        private Language preferredLanguage = Language.EN;
    }

    @Data
    public static class Login {
        @NotBlank(message = "Email or phone is required")
        @Size(max = 255)
        private String identifier;

        @NotBlank(message = "Password is required")
        @Size(max = 128)
        private String password;
    }

    @Data
    public static class RefreshToken {
        @NotBlank
        private String refreshToken;
    }

    @Data
    public static class Logout {
        private String refreshToken;
    }

    @Data
    public static class UpdateLanguage {
        @NotNull(message = "Language is required")
        private Language preferredLanguage;
    }

    /** Forgot-password step 3: reset with a verified OTP code — by phone or by email. */
    @Data
    public static class ResetPassword {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;

        @Email(message = "Enter a valid email address")
        private String email;

        @NotBlank(message = "OTP code is required")
        private String code;

        @NotBlank(message = "New password is required")
        @Size(min = 6, max = 72, message = "Password must be 6–72 characters")
        private String newPassword;

        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }

    /** Change the account phone number: the new number must be confirmed with a code sent to it. */
    @Data
    public static class ChangePhone {
        @NotBlank(message = "Phone is required")
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;

        @NotBlank(message = "Code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "The code is 6 digits")
        private String code;
    }

    /** Step 2 of the login flow when the account has 2FA enabled. */
    @Data
    public static class VerifyMfa {
        @NotBlank(message = "MFA token is required")
        private String mfaToken;

        @NotBlank(message = "Code is required")
        private String code;
    }

    /** Confirms 2FA setup — proves the user's authenticator app is actually in sync. */
    @Data
    public static class EnableTotp {
        @NotBlank(message = "Code is required")
        private String code;
    }
}
