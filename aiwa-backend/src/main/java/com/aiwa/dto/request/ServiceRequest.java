package com.aiwa.dto.request;

import com.aiwa.enums.PricingType;
import com.aiwa.enums.ServiceCategory;
import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ServiceRequest {

    @NotBlank(message = "Service name is required")
    @Size(max = 255, message = "{validation.text.too_long}")
    private String name;

    @Size(max = 255, message = "{validation.text.too_long}")
    private String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.0", inclusive = false, message = "Price must be positive")
    // L-9: numeric(10,2) overflowed with a 500.
    @DecimalMax(value = "1000000", message = "{validation.price.max}")
    @Digits(integer = 8, fraction = 2, message = "{validation.price.max}")
    private BigDecimal price;

    @NotNull(message = "Duration is required")
    @Min(value = 5, message = "Duration must be at least 5 minutes")
    // CR-13(b): from 24 hours the stored end time wraps and hides the booking from the overlap check.
    @Max(value = 480, message = "{validation.duration.max}")
    private Integer durationMinutes;

    private ServiceCategory category;

    /** Gap 2: fixed price or starts-at */
    private PricingType pricingType = PricingType.FIXED;

    /** Gap 2: does price include transport/Uber cost? */
    private boolean transportIncluded = false;
}
