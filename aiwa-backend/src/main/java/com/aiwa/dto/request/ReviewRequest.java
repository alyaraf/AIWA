package com.aiwa.dto.request;

import com.aiwa.enums.ReviewDirection;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.util.List;

@Data
public class ReviewRequest {

    @NotNull(message = "Booking ID is required")
    private Long bookingId;

    @NotNull(message = "Rating is required")
    @Min(1) @Max(5)
    private Integer rating;

    @Size(max = 1000)
    private String comment;

    /** Quick-tag chips shown in the design (e.g. "Punctual", "Skilled", "Friendly") */
    private List<String> quickTags;

    private ReviewDirection direction = ReviewDirection.CUSTOMER_TO_PROVIDER;
}
