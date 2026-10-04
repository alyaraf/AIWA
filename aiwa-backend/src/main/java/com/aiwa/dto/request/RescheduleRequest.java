package com.aiwa.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class RescheduleRequest {

    @NotNull(message = "New booking date is required")
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate bookingDate;

    @NotNull(message = "New start time is required")
    private LocalTime startTime;

    @jakarta.validation.constraints.Size(max = 255, message = "{validation.text.too_long}")
    private String reason;
}
