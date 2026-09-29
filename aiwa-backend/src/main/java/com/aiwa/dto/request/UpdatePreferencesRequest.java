package com.aiwa.dto.request;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class UpdatePreferencesRequest {

    @Min(value = 1, message = "Minimum radius must be at least 1 km")
    private Double searchRadiusMinKm;

    @Max(value = 100, message = "Maximum radius cannot exceed 100 km")
    private Double searchRadiusMaxKm;

    /** "Your area": where discovery starts when GPS isn't used. */
    @Size(max = 120, message = "Area name must be at most 120 characters")
    private String searchAreaLabel;

    @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0")
    private Double searchAreaLatitude;

    @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0")
    private Double searchAreaLongitude;

    /** true removes the saved area. */
    private Boolean clearSearchArea;
}
