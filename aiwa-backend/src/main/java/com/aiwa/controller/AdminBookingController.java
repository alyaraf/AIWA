package com.aiwa.controller;

import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ChatMessage;
import com.aiwa.repository.ChatMessageRepository;
import com.aiwa.service.BookingService;
import com.aiwa.service.impl.AuditService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/admin/bookings")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin Bookings", description = "Admin overrides on bookings")
public class AdminBookingController {

    private final BookingService bookingService;
    private final ChatMessageRepository chatRepo;
    private final AuditService auditService;

    @PostMapping("/{id}/force-cancel")
    @PreAuthorize(com.aiwa.security.Perms.FINANCE)
    @Operation(summary = "Force-cancel any active booking (ADMIN · Finance)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> forceCancel(
            @PathVariable Long id,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body) {
        ApiResponse.BookingDto dto = bookingService.adminForceCancel(id, FreeTextBody.pick(body, "reason", reason));
        auditService.record("BOOKING_FORCE_CANCELLED", "booking #" + id);
        return ResponseEntity.ok(ApiResponse.Success.of("Booking cancelled", dto));
    }

    @PostMapping("/{id}/resolve-dispute")
    @PreAuthorize(com.aiwa.security.Perms.FINANCE)
    @Operation(summary = "Resolve a disputed payment — outcome: PAID | UNPAID | NO_SHOW | CANCEL (ADMIN · Finance)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> resolveDispute(
            @PathVariable Long id,
            @RequestParam(required = false) String outcome,
            @RequestParam(required = false) Boolean paid,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body) {
        reason = FreeTextBody.pick(body, "reason", reason);
        String choice = outcome != null ? outcome : (Boolean.TRUE.equals(paid) ? "PAID" : "UNPAID");
        ApiResponse.BookingDto dto = bookingService.adminResolveDispute(id, choice, reason);
        auditService.record("DISPUTE_RESOLVED", "booking #" + id + " → " + choice.toLowerCase());
        return ResponseEntity.ok(ApiResponse.Success.of("Dispute resolved", dto));
    }

    @GetMapping("/{id}/chat")
    // M-3: private messages are for moderation (Support) and dispute evidence (Finance),
    // not every admin; every read is audited.
    @org.springframework.security.access.prepost.PreAuthorize(
            "hasAuthority('PERM_SUPPORT') or hasAuthority('PERM_FINANCE')")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    @Operation(summary = "Read the chat thread for a booking (ADMIN · Support or Finance, read-only, audited)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.ChatMessageDto>>> chat(@PathVariable Long id) {
        auditService.record("BOOKING_CHAT_VIEWED", "booking #" + id);
        return ResponseEntity.ok(ApiResponse.Success.of(
                chatRepo.findByBookingIdOrderByCreatedAtAsc(id).stream().map(this::toDto).toList()));
    }

    private ApiResponse.ChatMessageDto toDto(ChatMessage m) {
        return ApiResponse.ChatMessageDto.builder()
                .id(m.getId())
                .bookingId(m.getBooking().getId())
                .sender(ApiResponse.UserDto.builder()
                        .id(m.getSender().getId())
                        .fullName(m.getSender().getFullName())
                        .role(m.getSender().getRole())
                        .build())
                .type(m.getType())
                .message(m.getMessage())
                .readByRecipient(m.isReadByRecipient())
                .createdAt(m.getCreatedAt())
                .build();
    }
}
