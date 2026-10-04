package com.aiwa.dto.request;

import com.aiwa.enums.SafetyEventType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SafetyEventRequest {
    @NotNull
    private SafetyEventType type;
    @jakarta.validation.constraints.DecimalMin("-90") @jakarta.validation.constraints.DecimalMax("90")
    private Double latitude;
    @jakarta.validation.constraints.DecimalMin("-180") @jakarta.validation.constraints.DecimalMax("180")
    private Double longitude;
    /**
     * CR-16: when the phone took that fix and how accurate it is (metres), so
     * support can tell a fresh position from an old one. Optional (older apps
     * don't send them) and never validated: bad metadata must not block an SOS.
     */
    private java.time.Instant locationTime;
    @jakarta.validation.constraints.DecimalMin("0") @jakarta.validation.constraints.DecimalMax("100000")
    private Double locationAccuracy;
    @Size(max = 1000)
    private String notes;
}
