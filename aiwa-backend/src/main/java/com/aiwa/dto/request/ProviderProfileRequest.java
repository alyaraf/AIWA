package com.aiwa.dto.request;

import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.ProviderType;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ProviderProfileRequest {

    @NotBlank(message = "Business name is required")
    private String businessName;

    private String bio;

    private String address;

    private Double latitude;

    private Double longitude;

    private ProviderType providerType;

    private ServiceCategory primaryCategory;

    private Integer travelBufferMinutes;
}
