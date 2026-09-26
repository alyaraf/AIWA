package com.aiwa.dto.request;

import com.aiwa.enums.Gender;
import com.aiwa.enums.Language;
import com.aiwa.enums.UserRole;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class AuthRequest {

    @Data
    public static class Register {
        @NotBlank(message = "Full name is required")
        private String fullName;

        private String email;

        private String phone;

        @NotBlank(message = "Password is required")
        @Size(min = 6, message = "Password must be at least 6 characters")
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
        private String identifier;

        @NotBlank(message = "Password is required")
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

    /** Forgot-password step 3: reset with a verified OTP code. */
    @Data
    public static class ResetPassword {
        @NotBlank(message = "Phone is required")
        private String phone;

        @NotBlank(message = "OTP code is required")
        private String code;

        @NotBlank(message = "New password is required")
        @Size(min = 6, message = "Password must be at least 6 characters")
        private String newPassword;
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
