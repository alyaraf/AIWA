package com.aiwa.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SavedAddressRequest {
    @NotBlank
    private String label;
    @NotBlank
    private String addressLine;
    private Double latitude;
    private Double longitude;
    private Boolean defaultAddress;
}
