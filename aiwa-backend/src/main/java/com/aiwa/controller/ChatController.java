package com.aiwa.controller;

import com.aiwa.dto.request.ChatMessageRequest;
import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.*;
import com.aiwa.repository.*;
import com.aiwa.service.impl.AuditService;
import com.aiwa.service.impl.NotificationServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@Tag(name = "Chat", description = "Booking chat, reporting, and admin moderation")
public class ChatController {

    private static final String REMOVED_PLACEHOLDER = "[message removed by admin]";

    private final BookingRepository bookingRepo;
    private final ChatMessageRepository chatRepo;
    private final UserRepository userRepo;
    private final ModerationCaseRepository moderationRepo;
    private final NotificationServiceImpl notificationService;
    private final AuditService auditService;

    /** DR-028: per-account budgets (absent in plain unit tests). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.aiwa.service.impl.AccountRateLimiter limiter;

    @GetMapping("/bookings/{bookingId}/chat")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.ChatMessageDto>>> list(
            @PathVariable Long bookingId,
            @RequestParam(required = false) Long afterId,
            @AuthenticationPrincipal UserDetails userDetails) {
        Booking booking = loadAuthorizedBooking(bookingId, resolveUserId(userDetails));
        // AU-10: ?afterId= returns only newer messages, so the 5-second poll no longer
        // reloads the whole thread. Without it, the full thread as before.
        List<ChatMessage> messages = afterId == null
                ? chatRepo.findByBookingIdOrderByCreatedAtAsc(booking.getId())
                : chatRepo.findByBookingIdAndIdGreaterThanOrderByIdAsc(booking.getId(), afterId);
        return ResponseEntity.ok(ApiResponse.Success.of(messages.stream().map(this::toDto).toList()));
    }

    @PostMapping("/bookings/{bookingId}/chat")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ChatMessageDto>> send(
            @PathVariable Long bookingId,
            @Valid @RequestBody ChatMessageRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User sender = resolveUser(userDetails);
        if (limiter != null) limiter.check(sender.getId(), "chat", 30, java.time.Duration.ofMinutes(1));
        Booking booking = loadAuthorizedBooking(bookingId, sender.getId());
        // The thread closes 48 hours after the booking ends, so a finished (or
        // cancelled) booking can't be used to keep messaging someone.
        if (isClosedForChat(booking)) {
            throw new BusinessException("chat.error.closed");
        }
        ChatMessage message = chatRepo.save(ChatMessage.builder()
                .booking(booking)
                .sender(sender)
                .type(ChatMessageType.TEXT)
                .message(request.getMessage())
                .build());

        Long recipientId = booking.getCustomer().getId().equals(sender.getId())
                ? booking.getProvider().getUser().getId()
                : booking.getCustomer().getId();
        notificationService.send(recipientId, NotificationType.CHAT_MESSAGE,
                "New chat message", "رسالة جديدة",
                "You received a new message for booking #" + booking.getId(),
                "لديك رسالة جديدة للحجز رقم " + booking.getId(),
                booking.getId(), booking.getProvider().getId());

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Message sent", toDto(message)));
    }

    // ── Report a message (either party to the booking) ──────────────────────

    @PostMapping("/bookings/{bookingId}/chat/{messageId}/report")
    @Operation(summary = "Report an abusive/inappropriate chat message (either party to the booking)")
    public ResponseEntity<ApiResponse.Success<Void>> report(
            @PathVariable Long bookingId,
            @PathVariable Long messageId,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {
        return report(bookingId, messageId, FreeTextBody.pick(body, "reason", reason), userDetails);
    }

    public ResponseEntity<ApiResponse.Success<Void>> report(
            Long bookingId, Long messageId, String reason, UserDetails userDetails) {
        FreeTextBody.bounded(reason, 1000); // ModerationCase.reason is 1000 characters
        User reporter = resolveUser(userDetails);
        if (limiter != null) limiter.check(reporter.getId(), "report", 10, java.time.Duration.ofHours(1));
        loadAuthorizedBooking(bookingId, reporter.getId()); // 403s if not a party to this booking
        ChatMessage message = chatRepo.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Chat message", messageId));
        if (!message.getBooking().getId().equals(bookingId)) {
            throw new BusinessException("chat.error.wrong_booking");
        }
        // L-26: one open case per message; reporting it again only confirms it was received.
        if (moderationRepo.existsByStatusAndTargetTypeAndTargetId(
                com.aiwa.enums.ModerationStatus.OPEN, ModerationTargetType.CHAT_MESSAGE, messageId)) {
            return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.Success.of("Message reported", null));
        }
        moderationRepo.save(ModerationCase.builder()
                .targetType(ModerationTargetType.CHAT_MESSAGE)
                .targetId(messageId)
                .reason(reason != null && !reason.isBlank() ? reason : "Reported by " + reporter.getFullName())
                .build());
        auditService.record("CHAT_MESSAGE_REPORTED", "message #" + messageId + " (booking #" + bookingId + ")");
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.Success.of("Message reported", null));
    }

    // ── Admin moderation (mirrors the reported-reviews queue) ───────────────

    @PreAuthorize(com.aiwa.security.Perms.ANY_ADMIN)
    @GetMapping("/admin/chat/moderation")
    @Operation(summary = "Reported chat messages awaiting moderation, with the report reason (ADMIN)")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.ChatModerationDto>>> reportedMessages(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "200") int size) {
        // DR-028: one page at a time (the admin panel walks the pages).
        var cases = moderationRepo.findByStatusAndTargetTypeOrderByCreatedAtDesc(
                ModerationStatus.OPEN, ModerationTargetType.CHAT_MESSAGE, com.aiwa.util.Pages.admin(page, size));
        var out = new java.util.ArrayList<ApiResponse.ChatModerationDto>();
        for (var c : cases) {
            var message = chatRepo.findById(c.getTargetId()).orElse(null);
            if (message == null) continue;
            out.add(ApiResponse.ChatModerationDto.builder()
                    .moderationCaseId(c.getId())
                    .messageId(message.getId())
                    .bookingId(message.getBooking().getId())
                    .senderName(message.getSender() != null ? message.getSender().getFullName() : "User")
                    .message(message.getMessage())
                    .reason(c.getReason())
                    .removed(message.isRemoved())
                    .createdAt(c.getCreatedAt())
                    .build());
        }
        return ResponseEntity.ok(ApiResponse.Success.of(
                new org.springframework.data.domain.PageImpl<>(out, cases.getPageable(), cases.getTotalElements())));
    }

    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @PostMapping("/admin/chat/moderation/{caseId}/resolve")
    @Operation(summary = "Resolve a reported chat message: REMOVE (redact for both parties) / KEEP (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Void>> resolveReported(
            @PathVariable Long caseId,
            @RequestParam String action) {
        var moderationCase = moderationRepo.findById(caseId)
                .orElseThrow(() -> new ResourceNotFoundException("Moderation case", caseId));
        String choice = action == null ? "" : action.trim().toUpperCase();
        if (choice.equals("REMOVE")) {
            ChatMessage message = chatRepo.findById(moderationCase.getTargetId())
                    .orElseThrow(() -> new ResourceNotFoundException("Chat message", moderationCase.getTargetId()));
            message.setRemoved(true);
            chatRepo.save(message);
            moderationCase.setStatus(ModerationStatus.ACTIONED);
            auditService.record("CHAT_MESSAGE_REMOVED", "message #" + message.getId());
        } else if (choice.equals("KEEP")) {
            moderationCase.setStatus(ModerationStatus.DISMISSED);
            auditService.record("CHAT_REPORT_DISMISSED", "message #" + moderationCase.getTargetId());
        } else {
            throw new BusinessException("Unknown action: " + action);
        }
        moderationRepo.save(moderationCase);
        return ResponseEntity.ok(ApiResponse.Success.<Void>of("Report resolved", null));
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    static final java.time.Duration CHAT_GRACE = java.time.Duration.ofHours(48);

    /** Closed once the booking has ended (any terminal state) for more than the grace period. */
    static boolean isClosedForChat(Booking b) {
        com.aiwa.enums.BookingStatus s = b.getStatus();
        boolean ended = s == com.aiwa.enums.BookingStatus.COMPLETED || s == com.aiwa.enums.BookingStatus.NO_SHOW
                || s.isSlotReleasing();
        if (!ended) return false;
        java.time.LocalDateTime endedAt = b.endedAt();
        return endedAt != null && endedAt.plus(CHAT_GRACE).isBefore(java.time.LocalDateTime.now());
    }

    private Booking loadAuthorizedBooking(Long bookingId, Long userId) {
        Booking booking = bookingRepo.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        boolean allowed = booking.getCustomer().getId().equals(userId)
                || booking.getProvider().getUser().getId().equals(userId);
        if (!allowed) throw new com.aiwa.exception.ForbiddenException("error.access_denied");
        return booking;
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByLogin(ud.getUsername())
                .orElseThrow();
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return resolveUser(ud).getId();
    }

    private ApiResponse.ChatMessageDto toDto(ChatMessage m) {
        return ApiResponse.ChatMessageDto.builder()
                .id(m.getId())
                .bookingId(m.getBooking().getId())
                .sender(toUserDto(m.getSender()))
                .type(m.getType())
                .message(m.isRemoved() ? REMOVED_PLACEHOLDER : m.getMessage())
                .readByRecipient(m.isReadByRecipient())
                .removed(m.isRemoved())
                .createdAt(m.getCreatedAt())
                .build();
    }

    /**
     * The sender as the other party sees them. R2-11: phone and email were in
     * every message in every booking state; the Call button uses
     * GET /bookings/{id}/contact, which only answers while the booking is live.
     */
    private ApiResponse.UserDto toUserDto(User u) {
        return ApiResponse.UserDto.builder()
                .id(u.getId()).fullName(u.getFullName())
                .role(u.getRole())
                .active(u.isActive()).profileImageUrl(u.getProfileImageUrl()).build();
    }
}
