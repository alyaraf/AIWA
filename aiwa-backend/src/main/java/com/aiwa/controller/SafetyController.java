package com.aiwa.controller;

import com.aiwa.dto.request.SafetyEventRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.SafetyEventType;
import com.aiwa.exception.*;
import com.aiwa.repository.*;
import com.aiwa.service.impl.NotificationServiceImpl;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/bookings/{bookingId}/safety")
@RequiredArgsConstructor
public class SafetyController {

    private final BookingRepository bookingRepo;
    private final SafetyEventRepository safetyRepo;
    private final UserRepository userRepo;
    private final NotificationServiceImpl notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.SafetyEventDto>>> events(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal UserDetails userDetails) {
        Booking booking = loadAuthorizedBooking(bookingId, resolveUserId(userDetails));
        return ResponseEntity.ok(ApiResponse.Success.of(safetyRepo.findByBookingIdOrderByCreatedAtAsc(booking.getId())
                .stream().map(this::toDto).toList()));
    }

    @PostMapping
    public ResponseEntity<ApiResponse.Success<ApiResponse.SafetyEventDto>> record(
            @PathVariable Long bookingId,
            @Valid @RequestBody SafetyEventRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User actor = resolveUser(userDetails);
        Booking booking = loadAuthorizedBooking(bookingId, actor.getId());
        SafetyEvent event = safetyRepo.save(SafetyEvent.builder()
                .booking(booking)
                .actor(actor)
                .type(request.getType())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .notes(request.getNotes())
                .build());

        if (request.getType() == SafetyEventType.SOS) {
            notificationService.send(booking.getCustomer().getId(), NotificationType.SAFETY_ALERT,
                    "Safety alert", "تنبيه أمان",
                    "SOS triggered for booking #" + booking.getId(),
                    "تم إرسال تنبيه أمان للحجز رقم " + booking.getId(),
                    booking.getId(), booking.getProvider().getId());
            notificationService.send(booking.getProvider().getUser().getId(), NotificationType.SAFETY_ALERT,
                    "Safety alert", "تنبيه أمان",
                    "SOS triggered for booking #" + booking.getId(),
                    "تم إرسال تنبيه أمان للحجز رقم " + booking.getId(),
                    booking.getId(), booking.getProvider().getId());
        }

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Safety event recorded", toDto(event)));
    }

    private Booking loadAuthorizedBooking(Long bookingId, Long userId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean allowed = booking.getCustomer().getId().equals(userId)
                || booking.getProvider().getUser().getId().equals(userId);
        if (!allowed) throw new BusinessException("error.access_denied");
        return booking;
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow();
    }

    private Long resolveUserId(UserDetails ud) {
        return resolveUser(ud).getId();
    }

    private ApiResponse.SafetyEventDto toDto(SafetyEvent e) {
        return ApiResponse.SafetyEventDto.builder()
                .id(e.getId())
                .bookingId(e.getBooking().getId())
                .actor(ApiResponse.UserDto.builder().id(e.getActor().getId()).fullName(e.getActor().getFullName()).build())
                .type(e.getType())
                .latitude(e.getLatitude())
                .longitude(e.getLongitude())
                .notes(e.getNotes())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
