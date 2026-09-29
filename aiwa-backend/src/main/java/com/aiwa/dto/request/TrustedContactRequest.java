package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TrustedContactRequest {
    @NotBlank(message = "Name is required")
    @Size(max = 120, message = "Name must be at most 120 characters")
    private String name;

    /** International or Egyptian local format; digits, spaces, dashes and a leading + only. */
    @NotBlank(message = "Phone is required")
    @Pattern(regexp = "^\\+?[0-9][0-9 \\-]{6,19}$", message = "Enter a valid phone number")
    private String phone;

    @Size(max = 60, message = "Relationship must be at most 60 characters")
    private String relationship;
}
