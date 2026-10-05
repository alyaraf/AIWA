package com.aiwa.controller;

import com.aiwa.dto.request.SafetyEventRequest;
import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.SafetyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@Tag(name = "Safety", description = "In-booking safety events, SOS and the admin SOS queue")
public class SafetyController {

    private final SafetyService safetyService;
    private final UserRepository userRepo;

    @GetMapping("/bookings/{bookingId}/safety")
    @Operation(summary = "Safety timeline of a booking (the other party's SOS events are not shown)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.SafetyEventDto>>> events(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                safetyService.events(bookingId, resolveUserId(userDetails))));
    }

    @PostMapping("/bookings/{bookingId}/safety")
    @Operation(summary = "Record a safety event. type=SOS alerts support (push + SMS) and your trusted contacts; "
            + "the other party is not notified")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SafetyEventDto>> record(
            @PathVariable Long bookingId,
            @Valid @RequestBody SafetyEventRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Safety event recorded",
                        safetyService.record(bookingId, resolveUserId(userDetails), request)));
    }

    @PostMapping("/bookings/{bookingId}/safety/{eventId}/resolve")
    @Operation(summary = "\"I'm safe\" — close your own SOS")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SafetyEventDto>> resolveOwn(
            @PathVariable Long bookingId,
            @PathVariable Long eventId,
            @RequestParam(required = false) String notes,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Marked safe",
                safetyService.resolveOwn(bookingId, eventId, resolveUserId(userDetails),
                        FreeTextBody.pick(body, "notes", notes))));
    }

    // ── Admin SOS queue ───────────────────────────────────────────────────────

    @GetMapping("/admin/safety")
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "SOS queue — status OPEN (default) | RESOLVED | ALL (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.AdminSafetyEventDto>>> queue(
            @RequestParam(defaultValue = "OPEN") String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.Success.of(safetyService.adminQueue(status,
                PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100))))));
    }

    @PostMapping("/admin/safety/{eventId}/resolve")
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "Close an SOS with a note of what was done (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AdminSafetyEventDto>> adminResolve(
            @PathVariable Long eventId,
            @RequestParam(required = false) String notes,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("SOS closed",
                safetyService.adminResolve(eventId, resolveUserId(userDetails),
                        FreeTextBody.require(body, "notes", notes))));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }
}
