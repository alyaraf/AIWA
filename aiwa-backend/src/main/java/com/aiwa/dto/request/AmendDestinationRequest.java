package com.aiwa.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

/** B-05: the customer's explicit request to move an existing home visit to another of their saved addresses. */
@Data
public class AmendDestinationRequest {

    @NotNull(message = "A saved address is required")
    private Long savedAddressId;
}
