package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.StaffMember;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.StaffMemberRepository;
import com.aiwa.security.Perms;
import com.aiwa.service.impl.AuditService;
import com.aiwa.service.impl.PlatformSettingsServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;

/**
 * Per-provider overrides for commission and booking rules. Each value is
 * optional — clearing it (or never setting it) falls the provider back to the
 * platform-wide setting.
 */
@RestController
@RequestMapping("/admin/providers/{providerId}")
@RequiredArgsConstructor
@Tag(name = "Admin Provider Settings", description = "Per-provider commission and booking-rule overrides")
public class AdminProviderSettingsController {

    private final ProviderProfileRepository providerRepo;
    private final StaffMemberRepository staffRepo;
    private final PlatformSettingsServiceImpl platformSettings;
    private final AuditService auditService;

    @GetMapping("/settings")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    @Operation(summary = "Get this provider's commission + booking-rule overrides and the effective values (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> getSettings(
            @PathVariable Long providerId) {
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(load(providerId))));
    }

    /**
     * All staff, active and inactive. The public {@code GET /providers/{id}} (used
     * by the booking flow) deliberately only lists active staff — correct there,
     * but it meant an admin couldn't see who used to work at a shop. This is the
     * admin-only view with full history.
     */
    @GetMapping("/staff")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional(readOnly = true)
    @Operation(summary = "List this provider's staff, including inactive/departed ones (ADMIN)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.StaffMemberDto>>> staff(
            @PathVariable Long providerId) {
        load(providerId); // 404s cleanly if the provider doesn't exist
        List<ApiResponse.StaffMemberDto> dtos = staffRepo.findByProviderIdOrderByFullNameAsc(providerId).stream()
                .map(this::toStaffDto)
                .toList();
        return ResponseEntity.ok(ApiResponse.Success.of(dtos));
    }

    @PatchMapping("/commission")
    @PreAuthorize(Perms.FINANCE)
    @Transactional
    @Operation(summary = "Set or clear this provider's custom commission rate — applies to future bookings (ADMIN · Finance)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateCommission(
            @PathVariable Long providerId,
            @RequestParam(required = false) BigDecimal percent,
            @RequestParam(required = false, defaultValue = "false") boolean clear) {
        ProviderProfile provider = load(providerId);

        if (clear || percent == null) {
            provider.setCommissionOverridePercent(null);
        } else {
            platformSettings.validateCommissionPercent(percent);
            provider.setCommissionOverridePercent(percent);
        }
        providerRepo.save(provider);

        auditService.record("PROVIDER_COMMISSION_UPDATED", provider.getBusinessName() + " · "
                + (provider.getCommissionOverridePercent() != null
                    ? provider.getCommissionOverridePercent() + "%"
                    : "platform rate"));
        return ResponseEntity.ok(ApiResponse.Success.of("Commission updated", toDto(provider)));
    }

    @PatchMapping("/travel-fee")
    @PreAuthorize(Perms.FINANCE)
    @Transactional
    @Operation(summary = "Set or clear this provider's home-service travel fee — applies to future bookings (ADMIN · Finance)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateTravelFee(
            @PathVariable Long providerId,
            @RequestParam(required = false) BigDecimal amount,
            @RequestParam(required = false, defaultValue = "false") boolean clear) {
        ProviderProfile provider = load(providerId);
        if (clear || amount == null || amount.signum() == 0) {
            provider.setHomeServiceTravelFee(null);
        } else {
            if (amount.signum() < 0) {
                throw new BusinessException("provider.travel_fee.must_be_non_negative");
            }
            if (amount.compareTo(com.aiwa.service.impl.BookingServiceImpl.MAX_TRAVEL_QUOTE) > 0) {
                throw new com.aiwa.exception.BusinessException("provider.travel_fee.too_large");
            }
            provider.setHomeServiceTravelFee(amount);
        }
        providerRepo.save(provider);
        auditService.record("PROVIDER_TRAVEL_FEE_UPDATED", provider.getBusinessName() + " · "
                + (provider.getHomeServiceTravelFee() != null
                    ? provider.getHomeServiceTravelFee() + " EGP"
                    : "no travel fee"));
        return ResponseEntity.ok(ApiResponse.Success.of("Travel fee updated", toDto(provider)));
    }

    @PatchMapping("/booking-rules")
    @PreAuthorize(Perms.SUPER_ADMIN)
    @Transactional
    @Operation(summary = "Set or clear this provider's booking-rule overrides — applies to future bookings (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateBookingRules(
            @PathVariable Long providerId,
            @RequestParam(required = false) Integer cancellationCutoffHours,
            @RequestParam(required = false) BigDecimal providerCancelPenaltyPercent,
            @RequestParam(required = false) Long responseWindowMinutes,
            @RequestParam(required = false, defaultValue = "") String clear) {
        ProviderProfile provider = load(providerId);
        Set<String> toClear = clear.isBlank() ? Set.of() : Set.of(clear.split("\\s*,\\s*"));

        platformSettings.validateBookingRules(
                cancellationCutoffHours, providerCancelPenaltyPercent, responseWindowMinutes);

        if (toClear.contains("cancellationCutoffHours")) provider.setCancellationCutoffHoursOverride(null);
        else if (cancellationCutoffHours != null) provider.setCancellationCutoffHoursOverride(cancellationCutoffHours);

        if (toClear.contains("providerCancelPenaltyPercent")) provider.setProviderCancelPenaltyPercentOverride(null);
        else if (providerCancelPenaltyPercent != null) provider.setProviderCancelPenaltyPercentOverride(providerCancelPenaltyPercent);

        if (toClear.contains("responseWindowMinutes")) provider.setResponseWindowMinutesOverride(null);
        else if (responseWindowMinutes != null) provider.setResponseWindowMinutesOverride(responseWindowMinutes);

        providerRepo.save(provider);
        auditService.record("PROVIDER_BOOKING_RULES_UPDATED", provider.getBusinessName() + " · "
                + "cutoff=" + orDash(provider.getCancellationCutoffHoursOverride())
                + " penalty=" + orDash(provider.getProviderCancelPenaltyPercentOverride())
                + " window=" + orDash(provider.getResponseWindowMinutesOverride()));
        return ResponseEntity.ok(ApiResponse.Success.of("Booking rules updated", toDto(provider)));
    }

    private ProviderProfile load(Long providerId) {
        return providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
    }

    private static String orDash(Object v) {
        return v != null ? v.toString() : "platform";
    }

    private ApiResponse.ProviderSettingsDto toDto(ProviderProfile p) {
        return ApiResponse.ProviderSettingsDto.builder()
                .providerId(p.getId())
                .providerName(p.getBusinessName())
                .commissionOverridePercent(p.getCommissionOverridePercent())
                .effectiveCommissionPercent(platformSettings.getCommissionPercentFor(p))
                .platformCommissionPercent(platformSettings.getCommissionPercent())
                .cancellationCutoffHoursOverride(p.getCancellationCutoffHoursOverride())
                .providerCancelPenaltyPercentOverride(p.getProviderCancelPenaltyPercentOverride())
                .responseWindowMinutesOverride(p.getResponseWindowMinutesOverride())
                .effectiveCancellationCutoffHours(platformSettings.getCancellationCutoffHours(p))
                .effectiveProviderCancelPenaltyPercent(platformSettings.getProviderCancelPenaltyPercent(p))
                .effectiveResponseWindowMinutes(platformSettings.getResponseWindowMinutes(p))
                .platformCancellationCutoffHours(platformSettings.getCancellationCutoffHours())
                .platformProviderCancelPenaltyPercent(platformSettings.getProviderCancelPenaltyPercent())
                .platformResponseWindowMinutes(platformSettings.getResponseWindowMinutes())
                .homeServiceTravelFee(p.getHomeServiceTravelFee())
                .build();
    }

    private ApiResponse.StaffMemberDto toStaffDto(StaffMember s) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
                .phone(s.getPhone())
                .skills(s.getSkills())
                .active(s.isActive())
                .build();
    }
}
