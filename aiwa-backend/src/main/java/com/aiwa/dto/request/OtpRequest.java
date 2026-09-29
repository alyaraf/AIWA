package com.aiwa.dto.request;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

public class OtpRequest {

    /** Exactly one of phone (SMS) or email must be given. */
    @Data
    public static class SendOtp {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;

        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;

        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }

    @Data
    public static class VerifyOtp {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;

        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;

        @NotBlank(message = "Code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "The code is 6 digits")
        private String code;

        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }
}
