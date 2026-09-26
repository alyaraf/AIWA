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

    private Integer slotDurationMinutes = 30;

    private boolean available = true;
}
