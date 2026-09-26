package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

public class OtpRequest {

    @Data
    public static class SendOtp {
        @NotBlank(message = "Phone number is required")
        private String phone;
    }

    @Data
    public static class VerifyOtp {
        @NotBlank(message = "Phone number is required")
        private String phone;

        @NotBlank(message = "Code is required")
        private String code;
    }
}
