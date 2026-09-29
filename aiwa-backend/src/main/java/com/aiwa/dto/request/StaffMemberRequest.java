package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class StaffMemberRequest {
    @NotBlank
    @Size(max = 120)
    private String fullName;

    @Size(max = 80)
    private String title;

    @Pattern(regexp = "^[+]?[0-9][0-9 -]{6,19}$", message = "Enter a valid phone number")
    private String phone;

    @Size(max = 255)
    private String skills;

    private Boolean active;

    /**
     * Services this person performs (ids of the provider's own services). Omit to
     * leave the link unchanged; an empty list means "performs every service".
     */
    private List<Long> serviceIds;
}
