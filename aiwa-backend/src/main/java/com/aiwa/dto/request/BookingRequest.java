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

    private String paymentMethod = "CASH";

    private Boolean homeService = false;

    private String notes;
}
