package com.aiwa.controller;

import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.ComplaintServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import com.aiwa.security.Perms;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@Tag(name = "Complaints", description = "Customer complaint submission and admin resolution")
public class ComplaintController {

    private final ComplaintServiceImpl complaintService;
    private final UserRepository userRepo;
    private final com.aiwa.service.impl.NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AuditService auditService;

    /** DR-028: per-account budget (absent in plain unit tests). */
    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.aiwa.service.impl.AccountRateLimiter limiter;

    @PostMapping("/complaints")
    @Operation(summary = "Submit a complaint")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ComplaintDto>> submit(
            @RequestParam(required = false) Long targetProviderId,
            @RequestParam(required = false) Long bookingId,
            @RequestParam String category,
            @RequestParam(required = false) String description,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {

        description = FreeTextBody.require(body, "description", description);
        if (limiter != null) limiter.check(resolveUserId(userDetails), "complaint", 5, java.time.Duration.ofHours(1));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Complaint submitted",
                        complaintService.submit(resolveUserId(userDetails),
                                targetProviderId, bookingId, category, description)));
    }

    @GetMapping("/complaints/my")
    @Operation(summary = "Get my complaints")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> my(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                complaintService.getMyComplaints(resolveUserId(userDetails), com.aiwa.util.Pages.of(page, size))));
    }

    @GetMapping("/admin/complaints")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "List all complaints (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> adminList(
            @RequestParam(required = false) ComplaintStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                complaintService.adminGetAll(status, com.aiwa.util.Pages.admin(page, size))));
    }

    @PostMapping("/admin/complaints/{id}/resolve")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Resolve a complaint (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ComplaintDto>> resolve(
            @PathVariable Long id,
            @RequestParam(required = false) String notes,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {
        ApiResponse.ComplaintDto dto = complaintService.resolve(id, resolveUserId(userDetails),
                FreeTextBody.require(body, "notes", notes));
        auditService.record("COMPLAINT_RESOLVED", "complaint #" + id);
        return ResponseEntity.ok(ApiResponse.Success.of("Complaint resolved", dto));
    }

    @PostMapping("/admin/complaints/{id}/flag")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Flag a complaint for escalation (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> flag(@PathVariable Long id) {
        complaintService.flag(id);
        auditService.record("COMPLAINT_ESCALATED", "complaint #" + id);
        return ResponseEntity.ok(ApiResponse.Success.of("Complaint flagged", null));
    }

    /** Gap 5: flag a specific user (customer or provider) via their complaint */
    @PostMapping("/admin/users/{userId}/flag")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Flag a user for review (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> flagUser(
            @PathVariable Long userId,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body) {
        // Create a system-generated complaint/flag for the user
        complaintService.flagUser(userId, FreeTextBody.require(body, "reason", reason));
        return ResponseEntity.ok(ApiResponse.Success.of("User flagged for review", null));
    }

    /** Flag outcome: issue a formal warning to a user (customer or provider). */
    @PostMapping("/admin/users/{userId}/warn")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Send a warning to a user (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> warnUser(
            @PathVariable Long userId,
            @RequestParam(required = false) String reason,
            @RequestBody(required = false) FreeTextBody body) {
        reason = FreeTextBody.require(body, "reason", reason);
        User target = userRepo.findById(userId)
                .orElseThrow(() -> new com.aiwa.exception.ResourceNotFoundException("User", userId));
        notificationService.send(target.getId(),
                com.aiwa.enums.NotificationType.ACCOUNT_WARNING,
                "Warning from AIWA", "تحذير من AIWA",
                "You have received a warning: " + reason,
                "لقد تلقيت تحذيراً: " + reason,
                null, null);
        auditService.record("USER_WARNED", target.getFullName());
        return ResponseEntity.ok(ApiResponse.Success.of("Warning sent", null));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }
}
