package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.FileStorageServiceImpl;
import com.aiwa.service.impl.VerificationServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import java.io.File;
import org.springframework.data.domain.*;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import com.aiwa.security.Perms;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@Tag(name = "Verification", description = "Provider identity verification and admin approval")
public class VerificationController {

    private final VerificationServiceImpl verificationService;
    private final FileStorageServiceImpl fileStorageService;
    private final com.aiwa.service.impl.AuditService auditService;
    @Value("${aiwa.storage.private-path:uploads/private}")
    private String privatePath;

    private final UserRepository userRepo;
    private final com.aiwa.repository.ProviderProfileRepository providerRepo;

    @GetMapping("/admin/verification/counts")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Provider counts by verification status (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.VerificationCountsDto>> counts() {
        return ResponseEntity.ok(ApiResponse.Success.of(ApiResponse.VerificationCountsDto.builder()
                .pending(providerRepo.countByVerificationStatus(com.aiwa.enums.VerificationStatus.PENDING_VERIFICATION))
                .approved(providerRepo.countByVerificationStatus(com.aiwa.enums.VerificationStatus.APPROVED))
                .rejected(providerRepo.countByVerificationStatus(com.aiwa.enums.VerificationStatus.REJECTED))
                .suspended(providerRepo.countByVerificationStatus(com.aiwa.enums.VerificationStatus.SUSPENDED))
                .build()));
    }

    // ── Provider: submit documents ────────────────────────────────────────────

    @PostMapping("/provider/verification/documents")
    @Operation(summary = "Submit national ID + selfie for verification (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<Void>> submitDocuments(
            @RequestParam("nationalIdFront") MultipartFile nationalIdFront,
            @RequestParam("nationalIdBack")  MultipartFile nationalIdBack,
            @RequestParam("selfie")          MultipartFile selfie,
            @AuthenticationPrincipal UserDetails userDetails) {

        String frontPath  = fileStorageService.storePrivate(nationalIdFront, "national-id");
        String backPath   = fileStorageService.storePrivate(nationalIdBack, "national-id");
        String selfiePath = fileStorageService.storePrivate(selfie, "selfie");

        verificationService.submitDocuments(resolveUserId(userDetails), frontPath, backPath, selfiePath);
        return ResponseEntity.ok(ApiResponse.Success.of("Documents submitted. Pending review.", null));
    }

    // ── Admin: review queue ───────────────────────────────────────────────────

    @GetMapping("/admin/verification/pending")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "List providers pending verification (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderVerificationDto>>> pending(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                verificationService.getPendingVerifications(PageRequest.of(page, size))));
    }

    @GetMapping("/admin/verification")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "List providers by verification status (ADMIN)")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderVerificationDto>>> byStatus(
            @RequestParam VerificationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                verificationService.getByVerificationStatus(status, PageRequest.of(page, size))));
    }

    @PostMapping("/admin/verification/{providerId}/approve")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Approve a provider (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> approve(@PathVariable Long providerId) {
        verificationService.approve(providerId);
        auditService.record("PROVIDER_APPROVED", "provider #" + providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Provider approved", null));
    }

    @PostMapping("/admin/verification/{providerId}/reject")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Reject a provider with reason (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> reject(
            @PathVariable Long providerId,
            @RequestParam String reason) {
        verificationService.reject(providerId, reason);
        auditService.record("PROVIDER_REJECTED", "provider #" + providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Provider rejected", null));
    }

    @PostMapping("/admin/verification/{providerId}/request-info")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Request more information from a provider (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> requestInfo(
            @PathVariable Long providerId,
            @RequestParam String message) {
        verificationService.requestMoreInfo(providerId, message);
        auditService.record("PROVIDER_INFO_REQUESTED", "provider #" + providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Information requested from provider", null));
    }

    @PostMapping("/admin/verification/{providerId}/suspend")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Suspend a provider (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> suspend(@PathVariable Long providerId) {
        verificationService.suspend(providerId);
        auditService.record("PROVIDER_SUSPENDED", "provider #" + providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Provider suspended", null));
    }

    @PostMapping("/admin/verification/{providerId}/reactivate")
    @PreAuthorize(Perms.SUPPORT)
    @Operation(summary = "Reactivate a suspended provider (ADMIN · Support)")
    public ResponseEntity<ApiResponse.Success<Void>> reactivate(@PathVariable Long providerId) {
        verificationService.reactivate(providerId);
        auditService.record("PROVIDER_REACTIVATED", "provider #" + providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Provider reactivated", null));
    }

    /**
     * SRS BR-2: Admin-only endpoint to serve private verification docs.
     * Never exposed via public URL.
     */
    @GetMapping("/admin/verification/document")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Download a private verification document by its stored path (ADMIN only). "
            + "Only paths recorded on a provider profile are served; prefer /admin/verification/{providerId}/documents/{kind}.")
    public ResponseEntity<org.springframework.core.io.Resource> getDocument(
            @RequestParam String filePath) {
        // The old check was a substring match on the absolute path, so
        // "uploads/private/../../etc/passwd" passed. Now the path must be one a
        // provider actually submitted, and it must resolve inside the private root.
        if (!providerRepo.existsByNationalIdFrontPathOrNationalIdBackPathOrSelfiePath(filePath, filePath, filePath)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        auditService.record("VERIFICATION_DOCUMENT_VIEWED", filePath.replaceAll(".*/", ""));
        return serveDocument(filePath);
    }

    @GetMapping("/admin/verification/{providerId}/documents/{kind}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Stream one verification document of a provider — kind: id-front | id-back | selfie (ADMIN only)")
    public ResponseEntity<org.springframework.core.io.Resource> getDocumentByKind(
            @PathVariable Long providerId,
            @PathVariable String kind) {
        com.aiwa.entity.ProviderProfile p = providerRepo.findById(providerId)
                .orElseThrow(() -> new com.aiwa.exception.ResourceNotFoundException("Provider", providerId));
        String stored = switch (kind) {
            case "id-front" -> p.getNationalIdFrontPath();
            case "id-back" -> p.getNationalIdBackPath();
            case "selfie" -> p.getSelfiePath();
            default -> throw new com.aiwa.exception.BusinessException("Unknown document kind: " + kind);
        };
        if (stored == null) return ResponseEntity.notFound().build();
        auditService.record("VERIFICATION_DOCUMENT_VIEWED", "provider #" + providerId + " " + kind);
        return serveDocument(stored);
    }

    private ResponseEntity<org.springframework.core.io.Resource> serveDocument(String storedPath) {
        java.nio.file.Path path = fileStorageService.resolvePrivate(storedPath).orElse(null);
        if (path == null) return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        if (!java.nio.file.Files.isRegularFile(path)) return ResponseEntity.notFound().build();
        String name = path.getFileName().toString();
        MediaType type = name.endsWith(".png") ? MediaType.IMAGE_PNG
                : name.endsWith(".webp") ? MediaType.parseMediaType("image/webp")
                : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok()
                .contentType(type)
                .header("Content-Disposition", "inline; filename=\"" + name + "\"")
                .header("Cache-Control", "no-store")
                .body(new FileSystemResource(path));
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
