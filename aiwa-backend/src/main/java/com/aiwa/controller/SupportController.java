package com.aiwa.controller;

import com.aiwa.dto.request.SupportSettingsRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.SupportNumber;
import com.aiwa.entity.SupportSettings;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.SupportSettingsRepository;
import com.aiwa.service.impl.AuditService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;

@RestController
@RequestMapping("/support")
@RequiredArgsConstructor
@Tag(name = "Support", description = "WhatsApp support contact info and settings")
public class SupportController {

    private final SupportSettingsRepository supportRepo;
    private final AuditService auditService;

    @GetMapping("/contact")
    @Operation(summary = "Get WhatsApp support contact info (public)")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> contact() {
        SupportSettings settings = supportRepo.findFirstByWhatsappEnabledTrue().orElse(null);
        if (settings == null || !settings.isWhatsappEnabled()) {
            return ResponseEntity.ok(ApiResponse.Success.of("No support contact configured", null));
        }
        // Public callers only see the lines that are switched on. Fall back to the
        // legacy flat number for installs that predate the numbers list.
        List<SupportNumber> visible = enabledNumbers(settings);
        if (visible.isEmpty() && settings.getWhatsappNumber() != null && !settings.getWhatsappNumber().isBlank()) {
            visible = List.of(SupportNumber.builder()
                    .label("General").number(settings.getWhatsappNumber())
                    .displayNumber(settings.getWhatsappNumberDisplay() != null && !settings.getWhatsappNumberDisplay().isBlank()
                            ? settings.getWhatsappNumberDisplay() : settings.getWhatsappNumber())
                    .primary(true).enabled(true).build());
        }
        if (visible.isEmpty()) {
            return ResponseEntity.ok(ApiResponse.Success.of("No support contact configured", null));
        }
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(settings, visible)));
    }

    // ── Admin — edit support settings ────────────────────────────────────────

    @GetMapping("/admin/settings")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    @Operation(summary = "Get the current support settings (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> adminGet() {
        SupportSettings settings = getOrCreate();
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(settings, settings.getNumbers())));
    }

    @PatchMapping("/admin/settings")
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Transactional
    @Operation(summary = "Update support settings — numbers, hours, escalation email (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> adminUpdate(
            @Valid @RequestBody SupportSettingsRequest request) {
        SupportSettings settings = getOrCreate();

        if (request.getNumbers() != null) {
            List<SupportNumber> normalized = normalize(request.getNumbers());
            settings.getNumbers().clear();
            settings.getNumbers().addAll(normalized);
            syncPrimaryToLegacy(settings);
        }
        if (request.getAvailabilityHoursEn() != null) settings.setAvailabilityHoursEn(request.getAvailabilityHoursEn().trim());
        if (request.getAvailabilityHoursAr() != null) settings.setAvailabilityHoursAr(request.getAvailabilityHoursAr().trim());
        if (request.getSupportEmail() != null) settings.setSupportEmail(request.getSupportEmail().trim());
        if (request.getWhatsappEnabled() != null) settings.setWhatsappEnabled(request.getWhatsappEnabled());

        SupportSettings saved = supportRepo.save(settings);
        auditService.record("SUPPORT_SETTINGS_UPDATED",
                saved.getNumbers().size() + " number" + (saved.getNumbers().size() == 1 ? "" : "s"));
        return ResponseEntity.ok(ApiResponse.Success.of("Support settings updated", toDto(saved, saved.getNumbers())));
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    /**
     * Trims, drops blank lines, and guarantees exactly one primary among the
     * enabled lines. Rejects a list with no enabled line.
     */
    private List<SupportNumber> normalize(List<SupportSettingsRequest.Line> input) {
        List<SupportNumber> cleaned = new ArrayList<>();
        for (SupportSettingsRequest.Line line : input) {
            String number = line.getNumber() == null ? "" : line.getNumber().trim();
            if (number.isEmpty()) continue;
            String display = line.getDisplayNumber() == null || line.getDisplayNumber().isBlank()
                    ? number : line.getDisplayNumber().trim();
            String label = line.getLabel() == null ? "" : line.getLabel().trim();
            cleaned.add(SupportNumber.builder()
                    .label(label)
                    .number(number)
                    .displayNumber(display)
                    .primary(line.isPrimary())
                    .enabled(line.isEnabled())
                    .build());
        }
        if (cleaned.isEmpty()) {
            throw new BusinessException("Add at least one support number");
        }
        List<SupportNumber> enabled = cleaned.stream().filter(SupportNumber::isEnabled).toList();
        if (enabled.isEmpty()) {
            throw new BusinessException("At least one support number must be enabled");
        }
        // Exactly one primary, and it must be enabled.
        SupportNumber primary = enabled.stream().filter(SupportNumber::isPrimary).findFirst().orElse(enabled.get(0));
        for (SupportNumber n : cleaned) {
            n.setPrimary(n == primary);
        }
        return cleaned;
    }

    private void syncPrimaryToLegacy(SupportSettings settings) {
        settings.getNumbers().stream()
                .filter(SupportNumber::isPrimary)
                .findFirst()
                .ifPresent(primary -> {
                    settings.setWhatsappNumber(primary.getNumber());
                    settings.setWhatsappNumberDisplay(primary.getDisplayNumber());
                });
    }

    private List<SupportNumber> enabledNumbers(SupportSettings settings) {
        return settings.getNumbers().stream().filter(SupportNumber::isEnabled).toList();
    }

    /**
     * Loads the single settings row, creating it if missing. If a legacy install
     * has only the flat {@code whatsappNumber}, seed a matching primary line so
     * the list view is never empty.
     */
    private SupportSettings getOrCreate() {
        SupportSettings settings = supportRepo.findFirstByOrderByIdAsc().orElseGet(() -> supportRepo.save(
                SupportSettings.builder()
                        .whatsappNumber("").whatsappNumberDisplay("").supportEmail("")
                        .availabilityHoursEn("").whatsappEnabled(true).build()));
        if (settings.getNumbers().isEmpty() && settings.getWhatsappNumber() != null
                && !settings.getWhatsappNumber().isBlank()) {
            settings.getNumbers().add(SupportNumber.builder()
                    .label("General")
                    .number(settings.getWhatsappNumber())
                    .displayNumber(settings.getWhatsappNumberDisplay() != null
                            && !settings.getWhatsappNumberDisplay().isBlank()
                            ? settings.getWhatsappNumberDisplay() : settings.getWhatsappNumber())
                    .primary(true)
                    .enabled(true)
                    .build());
            settings = supportRepo.save(settings);
        }
        return settings;
    }

    private ApiResponse.SupportContactDto toDto(SupportSettings s, List<SupportNumber> numbers) {
        SupportNumber primary = numbers.stream().filter(SupportNumber::isPrimary).findFirst()
                .orElse(numbers.isEmpty() ? null : numbers.get(0));
        return ApiResponse.SupportContactDto.builder()
                .whatsappNumber(primary != null ? primary.getNumber() : s.getWhatsappNumber())
                .whatsappNumberDisplay(primary != null ? primary.getDisplayNumber() : s.getWhatsappNumberDisplay())
                .supportEmail(s.getSupportEmail())
                .availabilityHoursEn(s.getAvailabilityHoursEn())
                .availabilityHoursAr(s.getAvailabilityHoursAr())
                .whatsappEnabled(s.isWhatsappEnabled())
                .numbers(numbers.stream().map(n -> ApiResponse.SupportNumberDto.builder()
                        .label(n.getLabel())
                        .number(n.getNumber())
                        .displayNumber(n.getDisplayNumber())
                        .primary(n.isPrimary())
                        .enabled(n.isEnabled())
                        .build()).toList())
                .build();
    }
}
