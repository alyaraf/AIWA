package com.aiwa.dto.request;

import com.aiwa.enums.ProviderType;
import com.aiwa.enums.ServiceCategory;
import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class ProviderProfileRequest {

    @NotBlank(message = "Business name is required")
    @Size(max = 120, message = "Business name must be at most 120 characters")
    private String businessName;

    @Size(max = 255, message = "Bio must be at most 255 characters")
    private String bio;

    @Size(max = 255, message = "Address must be at most 255 characters")
    private String address;

    @DecimalMin(value = "-90.0", message = "Latitude must be between -90 and 90")
    @DecimalMax(value = "90.0", message = "Latitude must be between -90 and 90")
    private Double latitude;

    @DecimalMin(value = "-180.0", message = "Longitude must be between -180 and 180")
    @DecimalMax(value = "180.0", message = "Longitude must be between -180 and 180")
    private Double longitude;

    private ProviderType providerType;

    private ServiceCategory primaryCategory;

    @Min(value = 0, message = "Travel buffer cannot be negative")
    @Max(value = 240, message = "Travel buffer must be at most 240 minutes")
    private Integer travelBufferMinutes;

    /** How far the provider travels for home service (km). */
    @DecimalMin(value = "0.5", message = "Service radius must be at least 0.5 km")
    @DecimalMax(value = "200.0", message = "Service radius must be at most 200 km")
    private Double serviceRadiusKm;
}
