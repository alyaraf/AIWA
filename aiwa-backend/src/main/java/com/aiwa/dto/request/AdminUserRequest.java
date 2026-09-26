package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

public class AdminUserRequest {

    @Data
    public static class CreateAdmin {
        @NotBlank(message = "Full name is required")
        private String fullName;

        private String email;

        private String phone;

        @NotBlank(message = "Password is required")
        @Size(min = 12, message = "Admin password must be at least 12 characters")
        private String password;

        /** SUPPORT / FINANCE / SUPER_ADMIN — at least one required. */
        @NotEmpty(message = "Select at least one permission")
        private List<String> permissions;
    }

    /** Admin edits another user's contact details. All fields optional; only non-null ones change. */
    @Data
    public static class EditUser {
        @Size(min = 2, message = "Name is too short")
        private String fullName;
        private String email;
        private String phone;
    }
}
