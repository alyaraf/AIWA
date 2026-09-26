package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.TermsPolicy;
import com.aiwa.entity.User;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.TermsPolicyRepository;
import com.aiwa.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/terms")
@RequiredArgsConstructor
@Tag(name = "Terms & Policies", description = "Terms acceptance and policy management")
public class TermsController {

    private final TermsPolicyRepository termsRepo;
    private final UserRepository userRepo;
    private final com.aiwa.service.impl.AuditService auditService;

    // ── Public ────────────────────────────────────────────────────────────────

    @GetMapping("/latest")
    @Operation(summary = "Get the latest active terms for a given type (public)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> getLatest(
            @RequestParam(defaultValue = "CUSTOMER_TERMS") String type) {
        TermsPolicy policy = termsRepo.findFirstByTypeAndActiveTrueOrderByVersionDesc(type)
                .orElseThrow(() -> new BusinessException("No active terms found for type: " + type));
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(policy)));
    }

    @PostMapping("/accept")
    @Operation(summary = "Accept terms — stores version + timestamp on user profile")
    public ResponseEntity<ApiResponse.Success<Void>> accept(
            @RequestParam String version,
            @AuthenticationPrincipal UserDetails userDetails) {
        termsRepo.findByVersion(version)
                .orElseThrow(() -> new BusinessException("Terms version not found: " + version));

        User user = resolveUser(userDetails);
        user.setAcceptedTermsVersion(version);
        user.setTermsAcceptedAt(LocalDateTime.now());
        user.setTermsAccepted(true);
        userRepo.save(user);
        return ResponseEntity.ok(ApiResponse.Success.of("Terms accepted", null));
    }

    // ── Gap 7: Admin — manage policies ────────────────────────────────────────

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "List all terms/policies newest-first (ADMIN)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.TermsPolicyDto>>> listAll(
            @RequestParam(defaultValue = "CUSTOMER_TERMS") String type) {
        List<ApiResponse.TermsPolicyDto> list = termsRepo.findAll().stream()
                .filter(p -> type == null || type.isBlank() || type.equals(p.getType()))
                .sorted(java.util.Comparator.comparing(TermsPolicy::getCreatedAt,
                        java.util.Comparator.nullsLast(java.util.Comparator.reverseOrder())))
                .map(this::toDto).collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.Success.of(list));
    }

    @PostMapping
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Publish a new terms version — becomes Live, older ones deactivated (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> create(
            @RequestParam String version,
            @RequestParam(defaultValue = "CUSTOMER_TERMS") String type,
            @RequestParam String contentEn,
            @RequestParam(required = false) String contentAr) {

        if (termsRepo.findByVersion(version).isPresent())
            throw new BusinessException("Version already exists: " + version);

        // Only one version of a type is Live at a time.
        termsRepo.findAll().stream()
                .filter(p -> type.equals(p.getType()) && p.isActive())
                .forEach(p -> { p.setActive(false); termsRepo.save(p); });

        TermsPolicy policy = TermsPolicy.builder()
                .version(version).type(type)
                .contentEn(contentEn).contentAr(contentAr)
                .active(true).build();
        TermsPolicy saved = termsRepo.save(policy);
        auditService.record("POLICY_PUBLISHED", type + " " + version);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Version " + version + " published — users will re-accept on next open",
                        toDto(saved)));
    }

    @PatchMapping("/{id}/deactivate")
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Deactivate a terms version (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<Void>> deactivate(@PathVariable Long id) {
        TermsPolicy policy = termsRepo.findById(id)
                .orElseThrow(() -> new BusinessException("Policy not found"));
        policy.setActive(false);
        termsRepo.save(policy);
        return ResponseEntity.ok(ApiResponse.Success.of("Policy deactivated", null));
    }

    // ── Helper ────────────────────────────────────────────────────────────────

    private ApiResponse.TermsPolicyDto toDto(TermsPolicy p) {
        return ApiResponse.TermsPolicyDto.builder()
                .id(p.getId()).version(p.getVersion()).type(p.getType())
                .contentEn(p.getContentEn()).contentAr(p.getContentAr())
                .active(p.isActive()).createdAt(p.getCreatedAt()).build();
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow();
    }
}
