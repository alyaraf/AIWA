package com.aiwa.dto.request;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class SavedAddressRequest {
    @NotBlank(message = "Label is required")
    @Size(max = 60, message = "Label must be at most 60 characters")
    private String label;

    @NotBlank(message = "Address is required")
    @Size(max = 255, message = "Address must be at most 255 characters")
    private String addressLine;

    @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0")
    private Double latitude;

    @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0")
    private Double longitude;

    private Boolean defaultAddress;
}
