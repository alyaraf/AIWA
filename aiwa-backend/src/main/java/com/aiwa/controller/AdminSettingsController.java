package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.service.impl.PlatformSettingsServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

@RestController
@RequestMapping("/admin/settings")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin Settings", description = "Platform-wide, admin-editable settings")
public class AdminSettingsController {

    private final PlatformSettingsServiceImpl platformSettings;
    private final com.aiwa.service.impl.AuditService auditService;

    @GetMapping("/commission")
    @Operation(summary = "Get the current platform commission rate (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionSettingDto>> getCommission() {
        return ResponseEntity.ok(ApiResponse.Success.of(
                ApiResponse.CommissionSettingDto.builder()
                        .commissionPercent(platformSettings.getCommissionPercent())
                        .build()));
    }

    @PatchMapping("/commission")
    @PreAuthorize(com.aiwa.security.Perms.FINANCE)
    @Operation(summary = "Update the platform commission rate — applies to future bookings (ADMIN · Finance)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionSettingDto>> updateCommission(
            @RequestParam BigDecimal percent) {
        BigDecimal updated = platformSettings.updateCommissionPercent(percent).getCommissionPercent();
        auditService.record("COMMISSION_RATE_UPDATED", updated + "%");
        return ResponseEntity.ok(ApiResponse.Success.of("Commission rate updated",
                ApiResponse.CommissionSettingDto.builder().commissionPercent(updated).build()));
    }

    @GetMapping("/booking-rules")
    @Operation(summary = "Get booking rules — cancellation cutoff, provider penalty, response window (ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingRulesDto>> getBookingRules() {
        return ResponseEntity.ok(ApiResponse.Success.of(bookingRulesDto()));
    }

    @PatchMapping("/booking-rules")
    @PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Update booking rules — applies to future bookings (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.BookingRulesDto>> updateBookingRules(
            @RequestParam(required = false) Integer cancellationCutoffHours,
            @RequestParam(required = false) BigDecimal providerCancelPenaltyPercent,
            @RequestParam(required = false) Long responseWindowMinutes) {
        platformSettings.updateBookingRules(cancellationCutoffHours, providerCancelPenaltyPercent, responseWindowMinutes);
        auditService.record("BOOKING_RULES_UPDATED",
                "cutoff=" + platformSettings.getCancellationCutoffHours()
                        + "h penalty=" + platformSettings.getProviderCancelPenaltyPercent()
                        + "% window=" + platformSettings.getResponseWindowMinutes() + "m");
        return ResponseEntity.ok(ApiResponse.Success.of("Booking rules updated", bookingRulesDto()));
    }

    private ApiResponse.BookingRulesDto bookingRulesDto() {
        return ApiResponse.BookingRulesDto.builder()
                .cancellationCutoffHours(platformSettings.getCancellationCutoffHours())
                .providerCancelPenaltyPercent(platformSettings.getProviderCancelPenaltyPercent())
                .responseWindowMinutes(platformSettings.getResponseWindowMinutes())
                .build();
    }
}
