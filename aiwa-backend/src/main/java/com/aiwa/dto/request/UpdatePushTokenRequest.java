package com.aiwa.dto.request;

import com.aiwa.enums.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/** Registers (or clears, by sending a blank token) this device's push address. */
@Data
public class UpdatePushTokenRequest {
    @NotBlank(message = "Device token is required")
    private String token;

    @NotNull(message = "Device platform is required")
    private DevicePlatform platform;
}
