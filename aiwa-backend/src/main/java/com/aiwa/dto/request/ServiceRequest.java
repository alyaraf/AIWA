package com.aiwa.dto.request;

import com.aiwa.enums.PricingType;
import com.aiwa.enums.ServiceCategory;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ServiceRequest {

    @NotBlank(message = "Service name is required")
    private String name;

    private String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.0", inclusive = false, message = "Price must be positive")
    private BigDecimal price;

    @NotNull(message = "Duration is required")
    @Min(value = 5, message = "Duration must be at least 5 minutes")
    private Integer durationMinutes;

    private ServiceCategory category;

    /** Gap 2: fixed price or starts-at */
    private PricingType pricingType = PricingType.FIXED;

    /** Gap 2: does price include transport/Uber cost? */
    private boolean transportIncluded = false;
}
