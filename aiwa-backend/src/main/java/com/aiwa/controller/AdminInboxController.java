package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * Unified "things happening in the app that need admin attention" feed. Powers
 * the top-bar notification bell. Combines multiple sources into one timeline
 * sorted by newest first:
 *   - New / open complaints
 *   - Providers awaiting verification
 *   - Reported reviews and reported chat messages (moderation queue)
 *   - Disputed bookings
 *
 * Everything an admin's inbox should have without them having to click through
 * five different screens to find out something happened.
 */
@RestController
@RequestMapping("/admin/inbox")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin inbox", description = "Unified feed of things that need admin attention — complaints, verifications, reports, disputes")
public class AdminInboxController {

    private final ComplaintRepository complaintRepo;
    private final ProviderProfileRepository providerRepo;
    private final ModerationCaseRepository moderationRepo;
    private final BookingRepository bookingRepo;
    private final SafetyEventRepository safetyRepo;

    @GetMapping
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    @Operation(summary = "Recent admin-attention items across the whole app, newest first (ADMIN)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.InboxItemDto>>> inbox(
            @RequestParam(defaultValue = "20") int limit) {
        limit = Math.max(1, Math.min(limit, 100));
        int perSource = Math.max(1, Math.min(limit, 20));
        List<ApiResponse.InboxItemDto> items = new ArrayList<>();

        // Open SOS alerts — always listed first regardless of age.
        List<ApiResponse.InboxItemDto> sos = new ArrayList<>();
        safetyRepo.findByTypeAndResolvedOrderByCreatedAtDesc(com.aiwa.enums.SafetyEventType.SOS, false,
                        PageRequest.of(0, perSource))
                .forEach(e -> sos.add(ApiResponse.InboxItemDto.builder()
                        .id("sos-" + e.getId())
                        .kind("SOS")
                        .title("SOS — booking #" + e.getBooking().getId())
                        .body(e.getActor().getFullName() + (e.getNotes() != null ? " — " + e.getNotes() : ""))
                        .createdAt(e.getCreatedAt())
                        .targetRoute("safety")
                        .build()));

        // Complaints: users filing complaints against providers/customers.
        complaintRepo.findByStatusOrderByCreatedAtDesc(ComplaintStatus.OPEN, PageRequest.of(0, perSource))
                .forEach(c -> items.add(ApiResponse.InboxItemDto.builder()
                        .id("complaint-" + c.getId())
                        .kind("COMPLAINT")
                        .title("New complaint")
                        .body((c.getReporter() != null ? c.getReporter().getFullName() : "Someone")
                                + " · " + (c.getCategory() != null ? c.getCategory() : "")
                                + (c.getDescription() != null && !c.getDescription().isBlank()
                                    ? " — " + c.getDescription().substring(0, Math.min(60, c.getDescription().length()))
                                    : ""))
                        .createdAt(c.getCreatedAt())
                        .targetRoute("complaints")
                        .build()));

        // Provider signups awaiting verification.
        providerRepo.findByVerificationStatus(VerificationStatus.PENDING_VERIFICATION,
                PageRequest.of(0, perSource))
                .forEach(p -> items.add(ApiResponse.InboxItemDto.builder()
                        .id("verification-" + p.getId())
                        .kind("VERIFICATION")
                        .title("Provider awaiting verification")
                        .body(p.getBusinessName() + (p.getAddress() != null ? " · " + p.getAddress() : ""))
                        .createdAt(p.getCreatedAt())
                        .targetRoute("verifications")
                        .build()));

        // Moderation queue — reported reviews (targetType REVIEW) and reported
        // chat messages (targetType CHAT_MESSAGE). Same status enum, one query.
        moderationRepo.findByStatusOrderByCreatedAtDesc(ModerationStatus.OPEN).stream()
                .limit(perSource)
                .forEach(m -> {
                    boolean isChat = m.getTargetType() == ModerationTargetType.CHAT_MESSAGE;
                    // Route notes:
                    //   - REPORTED_CHAT → "chat-reports" (dedicated screen)
                    //   - REPORTED_REVIEW → "reviews" (the Reviews screen has a
                    //     "Reported" filter tab where these can actually be
                    //     resolved). The "moderation" route is Photo moderation
                    //     for gallery images — a different queue entirely.
                    //   - GALLERY_IMAGE → "moderation" (Photo moderation).
                    boolean isGallery = m.getTargetType() == ModerationTargetType.GALLERY_IMAGE;
                    String route;
                    String title;
                    if (isChat) { route = "chat-reports"; title = "Chat message reported"; }
                    else if (isGallery) { route = "moderation"; title = "Photo reported"; }
                    else { route = "reviews"; title = "Review reported"; }
                    items.add(ApiResponse.InboxItemDto.builder()
                            .id("moderation-" + m.getId())
                            .kind(isChat ? "REPORTED_CHAT" : (isGallery ? "REPORTED_PHOTO" : "REPORTED_REVIEW"))
                            .title(title)
                            .body(m.getReason() != null ? m.getReason() : "Awaiting review")
                            .createdAt(m.getCreatedAt())
                            .targetRoute(route)
                            .build());
                });

        // Disputed bookings — customer says they didn't pay, or something's wrong.
        bookingRepo.findByPaymentStatusOrderByCreatedAtDesc(PaymentStatus.DISPUTED).stream()
                .limit(perSource)
                .forEach(b -> items.add(ApiResponse.InboxItemDto.builder()
                        .id("dispute-" + b.getId())
                        .kind("DISPUTE")
                        .title("Payment dispute")
                        .body("BK-" + b.getId()
                                + (b.getCustomer() != null ? " · " + b.getCustomer().getFullName() : "")
                                + (b.getProvider() != null ? " → " + b.getProvider().getBusinessName() : ""))
                        .createdAt(b.getCreatedAt())
                        .targetRoute("bookings")
                        .build()));

        // Merge — newest first across all sources, capped at the requested limit.
        items.sort(Comparator.comparing(
                (ApiResponse.InboxItemDto it) -> it.getCreatedAt() == null ? LocalDateTime.MIN : it.getCreatedAt()
        ).reversed());
        sos.addAll(items);
        return ResponseEntity.ok(ApiResponse.Success.of(
                sos.size() > limit ? sos.subList(0, limit) : sos
        ));
    }
}
