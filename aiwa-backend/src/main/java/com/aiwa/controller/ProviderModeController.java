package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/provider/mode")
@PreAuthorize("hasRole('PROVIDER')")
@RequiredArgsConstructor
public class ProviderModeController {

    private final ProviderProfileRepository providerRepo;
    private final com.aiwa.service.impl.ProviderServiceImpl providerService;
    private final UserRepository userRepo;

    @PatchMapping
    public ApiResponse.Success<Void> updateMode(
            @RequestParam(required = false) Boolean vacationMode,
            @RequestParam(required = false) Boolean offlineMode,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        if (vacationMode != null) provider.setVacationMode(vacationMode);
        if (offlineMode != null) provider.setOfflineMode(offlineMode);
        providerRepo.save(provider);
        return ApiResponse.Success.of("Provider mode updated", null);
    }

    /**
     * Provider sets their own flat home-service travel fee. Pass a positive amount
     * to charge for travel; pass clear=true (or amount=0) to stop charging.
     * Existing bookings are unaffected — the fee is snapshotted at booking time.
     */
    @PatchMapping("/travel-fee")
    public ApiResponse.Success<Void> updateTravelFee(
            @RequestParam(required = false) java.math.BigDecimal amount,
            @RequestParam(required = false, defaultValue = "false") boolean clear,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        if (clear || amount == null || amount.signum() == 0) {
            provider.setHomeServiceTravelFee(null);
        } else {
            if (amount.signum() < 0) {
                throw new com.aiwa.exception.BusinessException("provider.travel_fee.must_be_non_negative");
            }
            provider.setHomeServiceTravelFee(amount);
        }
        providerRepo.save(provider);
        return ApiResponse.Success.of("Home-service travel fee updated", null);
    }

    /** How far the provider travels for home service (km, 0.5–200); clear=true removes it. */
    @PatchMapping("/service-radius")
    public ApiResponse.Success<ApiResponse.ProviderDetailDto> updateServiceRadius(
            @RequestParam(required = false) Double km,
            @RequestParam(required = false, defaultValue = "false") boolean clear,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (!clear && km == null) {
            throw new com.aiwa.exception.BusinessException("provider.service_radius.invalid");
        }
        return ApiResponse.Success.of("Service radius updated",
                providerService.updateServiceRadius(resolveUserId(userDetails), clear ? null : km));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
