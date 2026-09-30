package com.aiwa.controller;

import com.aiwa.dto.request.ReviewRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.ReviewService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@Tag(name = "Reviews", description = "Submit and view provider reviews")
public class ReviewController {

    private final com.aiwa.service.impl.ReviewServiceImpl reviewService;
    private final UserRepository userRepo;
    private final com.aiwa.service.impl.AuditService auditService;
    private final com.aiwa.repository.ModerationCaseRepository moderationRepo;
    private final com.aiwa.repository.ReviewRepository reviewRepo;

    @PostMapping("/reviews")
    @Operation(summary = "Submit a review for a completed booking")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> create(
            @Valid @RequestBody ReviewRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Review submitted",
                        reviewService.create(resolveUserId(userDetails), request)));
    }

    @GetMapping("/providers/{providerId}/reviews")
    @Operation(summary = "Customer reviews of a provider (public, paginated, with the provider's replies)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> getByProvider(
            @PathVariable Long providerId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                reviewService.getByProvider(providerId, pageOf(page, size))));
    }

    @GetMapping("/reviews/my")
    @Operation(summary = "Reviews I have written (totalElements = my review count)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> mine(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                reviewService.getMine(resolveUserId(userDetails), pageOf(page, size))));
    }

    @PostMapping("/provider/reviews/{id}/reply")
    @org.springframework.security.access.prepost.PreAuthorize("hasRole('PROVIDER')")
    @Operation(summary = "Reply publicly to a customer review of your business (PROVIDER); sending again edits the reply")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> reply(
            @PathVariable Long id,
            @RequestBody java.util.Map<String, String> body,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of("Reply saved",
                reviewService.reply(resolveUserId(userDetails), id, body.get("reply"))));
    }

    private static Pageable pageOf(int page, int size) {
        return PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 200)));
    }

    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @PatchMapping("/admin/reviews/{id}/visibility")
    @Operation(summary = "Hide or unhide a review; recomputes the provider rating (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> setVisibility(
            @PathVariable Long id,
            @RequestParam boolean hidden) {
        ApiResponse.ReviewDto dto = reviewService.setVisibility(id, hidden);
        auditService.record(hidden ? "REVIEW_HIDDEN" : "REVIEW_RESTORED", "review #" + id);
        return ResponseEntity.ok(ApiResponse.Success.of(hidden ? "Review hidden" : "Review restored", dto));
    }

    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.ANY_ADMIN)
    @GetMapping("/admin/reviews/moderation")
    @Operation(summary = "Reported reviews awaiting moderation, with the report reason (ADMIN)")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<java.util.List<ApiResponse.ReviewModerationDto>>> reportedReviews() {
        var cases = moderationRepo.findByStatusAndTargetTypeOrderByCreatedAtDesc(
                com.aiwa.enums.ModerationStatus.OPEN, com.aiwa.enums.ModerationTargetType.REVIEW);
        var out = new java.util.ArrayList<ApiResponse.ReviewModerationDto>();
        for (var c : cases) {
            var review = reviewRepo.findById(c.getTargetId()).orElse(null);
            if (review == null) continue;
            out.add(ApiResponse.ReviewModerationDto.builder()
                    .moderationCaseId(c.getId())
                    .reviewId(review.getId())
                    .authorName(review.getUser() != null ? review.getUser().getFullName() : "User")
                    .providerName(review.getProvider() != null ? review.getProvider().getBusinessName() : "Provider")
                    .rating(review.getRating())
                    .comment(review.getComment())
                    .reason(c.getReason())
                    .hidden(review.isHidden())
                    .createdAt(c.getCreatedAt())
                    .build());
        }
        return ResponseEntity.ok(ApiResponse.Success.of(out));
    }

    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @PostMapping("/admin/reviews/moderation/{caseId}/resolve")
    @Operation(summary = "Resolve a reported-review case: REMOVE (hide + recompute) / HIDE / KEEP (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Void>> resolveReported(
            @PathVariable Long caseId,
            @RequestParam String action) {
        var moderationCase = moderationRepo.findById(caseId)
                .orElseThrow(() -> new com.aiwa.exception.ResourceNotFoundException("Moderation case", caseId));
        String choice = action == null ? "" : action.trim().toUpperCase();
        if (choice.equals("REMOVE") || choice.equals("HIDE")) {
            reviewService.setVisibility(moderationCase.getTargetId(), true);
            moderationCase.setStatus(com.aiwa.enums.ModerationStatus.ACTIONED);
            auditService.record("REVIEW_" + choice, "review #" + moderationCase.getTargetId());
        } else if (choice.equals("KEEP")) {
            moderationCase.setStatus(com.aiwa.enums.ModerationStatus.DISMISSED);
            auditService.record("REVIEW_REPORT_DISMISSED", "review #" + moderationCase.getTargetId());
        } else {
            throw new com.aiwa.exception.BusinessException("Unknown action: " + action);
        }
        moderationRepo.save(moderationCase);
        return ResponseEntity.ok(ApiResponse.Success.<Void>of("Report resolved", null));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
