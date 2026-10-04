package com.aiwa.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.DayOfWeek;
import java.time.LocalTime;

@Data
public class AvailabilityRequest {

    /** Optional: scope this availability to a specific staff member (shop providers). */
    private Long staffMemberId;

    @NotNull
    private DayOfWeek dayOfWeek;

    @NotNull
    private LocalTime startTime;

    @NotNull
    private LocalTime endTime;

    @jakarta.validation.constraints.Min(value = 5, message = "Slots must be at least 5 minutes")
    @jakarta.validation.constraints.Max(value = 240, message = "Slots must be at most 240 minutes")
    private Integer slotDurationMinutes = 30;

    private boolean available = true;
}
