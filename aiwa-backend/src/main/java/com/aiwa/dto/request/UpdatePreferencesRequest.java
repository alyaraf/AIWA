package com.aiwa.dto.request;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import lombok.Data;

@Data
public class UpdatePreferencesRequest {

    @Min(value = 1, message = "Minimum radius must be at least 1 km")
    private Double searchRadiusMinKm;

    @Max(value = 100, message = "Maximum radius cannot exceed 100 km")
    private Double searchRadiusMaxKm;
}
