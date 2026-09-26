package com.aiwa.controller;

import com.aiwa.dto.request.ModerationRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.NotificationServiceImpl;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/admin/moderation")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class ModerationController {

    private final ModerationCaseRepository moderationRepo;
    private final UserRepository userRepo;
    private final NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AuditService auditService;

    @GetMapping
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.ModerationCaseDto>>> list(
            @RequestParam(defaultValue = "OPEN") ModerationStatus status) {
        return ResponseEntity.ok(ApiResponse.Success.of(moderationRepo.findByStatusOrderByCreatedAtDesc(status)
                .stream().map(this::toDto).toList()));
    }

    @PostMapping
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    public ResponseEntity<ApiResponse.Success<ApiResponse.ModerationCaseDto>> create(
            @Valid @RequestBody ModerationRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User admin = resolveUser(userDetails);
        ModerationCase moderationCase = moderationRepo.save(ModerationCase.builder()
                .targetType(request.getTargetType())
                .targetId(request.getTargetId())
                .reason(request.getReason())
                .admin(admin)
                .adminNotes(request.getAdminNotes())
                .build());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Moderation case opened", toDto(moderationCase)));
    }

    @PatchMapping("/{id}/action")
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    public ResponseEntity<ApiResponse.Success<ApiResponse.ModerationCaseDto>> action(
            @PathVariable Long id,
            @RequestParam ModerationStatus status,
            @RequestParam(required = false) String notes,
            @AuthenticationPrincipal UserDetails userDetails) {
        ModerationCase moderationCase = moderationRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Moderation case", id));
        moderationCase.setAdmin(resolveUser(userDetails));
        moderationCase.setStatus(status);
        if (notes != null) moderationCase.setAdminNotes(notes);
        ModerationCase saved = moderationRepo.save(moderationCase);
        auditService.record("MODERATION_" + status, moderationCase.getTargetType() + " #" + moderationCase.getTargetId());
        notificationService.send(resolveUser(userDetails).getId(), NotificationType.MODERATION_ACTION,
                "Moderation action recorded", "تم تسجيل إجراء المراجعة",
                "Moderation case #" + id + " is now " + status,
                "حالة المراجعة رقم " + id + " أصبحت " + status,
                null, null);
        return ResponseEntity.ok(ApiResponse.Success.of("Moderation action saved", toDto(saved)));
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow();
    }

    private ApiResponse.ModerationCaseDto toDto(ModerationCase c) {
        return ApiResponse.ModerationCaseDto.builder()
                .id(c.getId())
                .targetType(c.getTargetType())
                .targetId(c.getTargetId())
                .reason(c.getReason())
                .status(c.getStatus())
                .adminNotes(c.getAdminNotes())
                .createdAt(c.getCreatedAt())
                .build();
    }
}
