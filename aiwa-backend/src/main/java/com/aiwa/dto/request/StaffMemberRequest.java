package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class StaffMemberRequest {
    @NotBlank
    private String fullName;
    private String title;
    private String phone;
    private String skills;
    private Boolean active;
}
