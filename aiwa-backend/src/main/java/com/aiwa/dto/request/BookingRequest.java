package com.aiwa.dto.request;

import com.aiwa.enums.BookingType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
public class BookingRequest {

    @NotNull(message = "Provider ID is required")
    private Long providerId;

    @NotNull(message = "Service ID is required")
    private Long serviceId;

    private Long staffMemberId;

    private Long savedAddressId;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate bookingDate;

    private LocalTime startTime;

    @NotNull(message = "Booking type is required")
    private BookingType bookingType = BookingType.SCHEDULED;

    /** Cash only for v1; any other value is ignored and stored as CASH. */
    private String paymentMethod = "CASH";

    private Boolean homeService = false;

    @jakarta.validation.constraints.Size(max = 255, message = "Notes must be at most 255 characters")
    private String notes;
}
