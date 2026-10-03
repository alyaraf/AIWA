package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class UpdateProfileRequest {

    @NotBlank(message = "Full name is required")
    private String fullName;

    private String email;

    /** Needed when the email changes (CR-05). */
    @jakarta.validation.constraints.Size(max = 128)
    private String currentPassword;

    private String profileImageUrl;
}
