package com.aiwa.controller;

import com.aiwa.dto.request.FreeTextBody;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.TermsPolicy;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.TermsPolicyRepository;
import com.aiwa.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

@RestController
@RequestMapping("/terms")
@RequiredArgsConstructor
@Tag(name = "Terms & Policies", description = "Terms acceptance and policy management")
public class TermsController {

    /** Document types the apps and the admin panel know how to show. */
    static final Set<String> TYPES = Set.of("CUSTOMER_TERMS", "PROVIDER_TERMS", "PRIVACY", "SAFETY");

    private final TermsPolicyRepository termsRepo;
    private final UserRepository userRepo;
    private final com.aiwa.service.impl.AuditService auditService;

    // ── Public ────────────────────────────────────────────────────────────────

    @GetMapping("/latest")
    @Operation(summary = "Get the latest active terms for a given type (public)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> getLatest(
            @RequestParam(defaultValue = "CUSTOMER_TERMS") String type) {
        TermsPolicy policy = termsRepo.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc(validType(type))
                .orElseThrow(() -> new ResourceNotFoundException("No active terms found for type: " + type));
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(policy)));
    }

    @PostMapping("/accept")
    @Transactional
    @Operation(summary = "Accept the live terms version — stores version + timestamp on the user. "
            + "type defaults to PROVIDER_TERMS for providers and CUSTOMER_TERMS for everyone else.")
    public ResponseEntity<ApiResponse.Success<Void>> accept(
            @RequestParam String version,
            @RequestParam(required = false) String type,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        String docType = type != null ? validType(type)
                : (user.getRole() == UserRole.PROVIDER ? "PROVIDER_TERMS" : "CUSTOMER_TERMS");
        TermsPolicy policy = termsRepo.findByTypeAndVersion(docType, version)
                .orElseThrow(() -> new BusinessException("Terms version not found: " + version));
        // Accepting a superseded version would leave the user on outdated terms
        // while the app believes they are current.
        if (!policy.isActive()) {
            throw new BusinessException("Terms version " + version + " is no longer current");
        }

        user.setAcceptedTermsVersion(version);
        user.setTermsAcceptedAt(LocalDateTime.now());
        user.setTermsAccepted(true);
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of("Terms accepted", null));
    }

    // ── Admin — manage policies ───────────────────────────────────────────────

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "List all versions of one document type, newest first (ADMIN)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.TermsPolicyDto>>> listAll(
            @RequestParam(defaultValue = "CUSTOMER_TERMS") String type) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                termsRepo.findByTypeOrderByCreatedAtDescIdDesc(validType(type)).stream().map(this::toDto).toList()));
    }

    @PostMapping
    @Transactional
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Publish a new terms version — becomes Live, older ones of the same type deactivated (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> create(
            @RequestBody(required = false) FreeTextBody body,
            @RequestParam(required = false) String version,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) String contentEn,
            @RequestParam(required = false) String contentAr,
            @RequestParam(required = false) String pdfUrl,
            @RequestParam(required = false) String changeNote) {
        // CR-21: a full policy does not fit in a URL; the JSON body wins, the old parameters still work.
        version = FreeTextBody.require(body, "version", version);
        contentEn = FreeTextBody.require(body, "contentEn", contentEn);
        contentAr = FreeTextBody.pick(body, "contentAr", contentAr);
        pdfUrl = FreeTextBody.pick(body, "pdfUrl", pdfUrl);
        changeNote = FreeTextBody.pick(body, "changeNote", changeNote);
        String chosenType = FreeTextBody.pick(body, "type", type);
        String docType = validType(chosenType == null ? "CUSTOMER_TERMS" : chosenType);
        if (version == null || version.isBlank() || version.length() > 32) {
            throw new BusinessException("Version must be 1–32 characters");
        }
        if (contentEn == null || contentEn.isBlank()) {
            throw new BusinessException("English content is required");
        }
        if (pdfUrl != null && !pdfUrl.isBlank() && !pdfUrl.startsWith("https://") && !pdfUrl.startsWith("/")) {
            throw new BusinessException("PDF link must be an https:// URL or a path on this server");
        }
        if (termsRepo.existsByTypeAndVersion(docType, version.trim()))
            throw new BusinessException("Version already exists: " + version);

        // Only one version of a type is Live at a time.
        termsRepo.findByTypeAndActiveTrue(docType).forEach(p -> { p.setActive(false); termsRepo.save(p); });

        TermsPolicy saved = termsRepo.save(TermsPolicy.builder()
                .version(version.trim()).type(docType)
                .contentEn(contentEn).contentAr(contentAr == null || contentAr.isBlank() ? null : contentAr)
                .pdfUrl(pdfUrl == null || pdfUrl.isBlank() ? null : pdfUrl.trim())
                .changeNote(changeNote == null || changeNote.isBlank() ? null
                        : changeNote.strip().substring(0, Math.min(changeNote.strip().length(), 500)))
                .publishedBy(publisherName())
                .active(true).build());
        auditService.record("POLICY_PUBLISHED", docType + " " + saved.getVersion());

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Version " + saved.getVersion()
                        + " published — users will re-accept on next open", toDto(saved)));
    }

    @PatchMapping("/{id}/deactivate")
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Deactivate a terms version (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<Void>> deactivate(@PathVariable Long id) {
        TermsPolicy policy = termsRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Policy", id));
        policy.setActive(false);
        termsRepo.save(policy);
        auditService.record("POLICY_DEACTIVATED", policy.getType() + " " + policy.getVersion());
        return ResponseEntity.ok(ApiResponse.Success.of("Policy deactivated", null));
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private static String validType(String type) {
        String t = type == null ? "" : type.trim().toUpperCase();
        if (!TYPES.contains(t)) throw new BusinessException("Unknown terms type: " + type);
        return t;
    }

    private ApiResponse.TermsPolicyDto toDto(TermsPolicy p) {
        return ApiResponse.TermsPolicyDto.builder()
                .id(p.getId()).version(p.getVersion()).type(p.getType())
                .contentEn(p.getContentEn()).contentAr(p.getContentAr())
                .pdfUrl(p.getPdfUrl())
                .changeNote(p.getChangeNote()).publishedBy(p.getPublishedBy())
                .active(p.isActive()).createdAt(p.getCreatedAt()).build();
    }

    /** The publishing admin's name (falls back to their login). */
    private String publisherName() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) return null;
        return userRepo.findByLogin(auth.getName())
                .map(User::getFullName)
                .orElse(auth.getName());
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByLogin(ud.getUsername())
                .orElseThrow();
    }
}
