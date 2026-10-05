package com.aiwa.controller;

import com.aiwa.dto.request.ModerationRequest;
import com.aiwa.dto.request.FreeTextBody;
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
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/admin/moderation")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class ModerationController {

    private final ModerationCaseRepository moderationRepo;
    private final GalleryImageRepository galleryRepo;
    private final UserRepository userRepo;
    private final NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AuditService auditService;

    @GetMapping
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.ModerationCaseDto>>> list(
            @RequestParam(defaultValue = "OPEN") ModerationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "200") int size) {
        // DR-028: paged; the admin panel walks the pages.
        return ResponseEntity.ok(ApiResponse.Success.of(moderationRepo
                .findByStatusOrderByCreatedAtDesc(status, com.aiwa.util.Pages.admin(page, size))
                .map(this::toDto)));
    }

    @PostMapping
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Transactional
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

    /**
     * ACTIONED on a GALLERY_IMAGE case hides that photo from the public gallery
     * (before, the status changed but the photo stayed visible). DISMISSED leaves
     * it as is; re-opening a case restores a hidden photo.
     */
    @PatchMapping("/{id}/action")
    @PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.ModerationCaseDto>> action(
            @PathVariable Long id,
            @RequestParam ModerationStatus status,
            @RequestParam(required = false) String notes,
            @RequestBody(required = false) FreeTextBody body,
            @AuthenticationPrincipal UserDetails userDetails) {
        notes = FreeTextBody.bounded(FreeTextBody.pick(body, "notes", notes), 1000); // ModerationCase.adminNotes
        ModerationCase moderationCase = moderationRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Moderation case", id));
        moderationCase.setAdmin(resolveUser(userDetails));
        moderationCase.setStatus(status);
        if (notes != null) moderationCase.setAdminNotes(notes);

        if (moderationCase.getTargetType() == ModerationTargetType.GALLERY_IMAGE) {
            galleryRepo.findById(moderationCase.getTargetId()).ifPresent(image -> {
                boolean hide = status == ModerationStatus.ACTIONED;
                if (image.isHidden() != hide) {
                    image.setHidden(hide);
                    galleryRepo.save(image);
                    if (hide) {
                        notificationService.send(image.getProvider().getUser().getId(), NotificationType.MODERATION_ACTION,
                                "A gallery photo was hidden", "تم إخفاء صورة من معرض أعمالك",
                                "One of your gallery photos was hidden after review because it breaks the content rules.",
                                "تم إخفاء إحدى صور معرض أعمالك بعد المراجعة لمخالفتها قواعد المحتوى.",
                                null, image.getProvider().getId());
                    }
                }
            });
        }

        ModerationCase saved = moderationRepo.save(moderationCase);
        auditService.record("MODERATION_" + status, moderationCase.getTargetType() + " #" + moderationCase.getTargetId());
        return ResponseEntity.ok(ApiResponse.Success.of("Moderation action saved", toDto(saved)));
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByLogin(ud.getUsername())
                .orElseThrow();
    }

    private ApiResponse.ModerationCaseDto toDto(ModerationCase c) {
        ApiResponse.ModerationCaseDto.ModerationCaseDtoBuilder b = ApiResponse.ModerationCaseDto.builder()
                .id(c.getId())
                .targetType(c.getTargetType())
                .targetId(c.getTargetId())
                .reason(c.getReason())
                .status(c.getStatus())
                .adminNotes(c.getAdminNotes())
                .createdAt(c.getCreatedAt());
        if (c.getTargetType() == ModerationTargetType.GALLERY_IMAGE) {
            galleryRepo.findById(c.getTargetId()).ifPresent(img -> b
                    .imageUrl(img.getUrl())
                    .imageHidden(img.isHidden())
                    .providerId(img.getProvider().getId())
                    .providerName(img.getProvider().getBusinessName()));
        }
        return b.build();
    }
}
