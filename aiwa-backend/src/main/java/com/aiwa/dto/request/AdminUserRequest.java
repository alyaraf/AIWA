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
        @Size(max = 255, message = "{validation.text.too_long}")
        private String fullName;

        @Size(max = 255, message = "{validation.text.too_long}")
        private String email;

        @Size(max = 32, message = "{validation.text.too_long}")
        private String phone;

        @NotBlank(message = "Password is required")
        // L-9: BCrypt only reads the first 72 bytes; a longer password was silently truncated.
        @Size(min = 12, max = 72, message = "Admin password must be 12 to 72 characters")
        private String password;

        /** SUPPORT / FINANCE / SUPER_ADMIN — at least one required. */
        @NotEmpty(message = "Select at least one permission")
        private List<String> permissions;
    }

    /** Admin edits another user's contact details. All fields optional; only non-null ones change. */
    @Data
    public static class EditUser {
        @Size(min = 2, max = 255, message = "Name must be 2 to 255 characters")
        private String fullName;
        @Size(max = 255, message = "{validation.text.too_long}")
        private String email;
        @Size(max = 32, message = "{validation.text.too_long}")
        private String phone;
    }
}
