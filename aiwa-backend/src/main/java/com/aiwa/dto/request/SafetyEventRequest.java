package com.aiwa.dto.request;

import com.aiwa.enums.SafetyEventType;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class SafetyEventRequest {
    @NotNull
    private SafetyEventType type;
    private Double latitude;
    private Double longitude;
    @Size(max = 1000)
    private String notes;
}
