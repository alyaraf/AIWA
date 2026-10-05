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
            if (amount.compareTo(com.aiwa.service.impl.BookingServiceImpl.MAX_TRAVEL_QUOTE) > 0) {
                throw new com.aiwa.exception.BusinessException("provider.travel_fee.too_large");
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

    /**
     * Gap (in minutes, 0-60) kept between two home visits. A narrow update (audit M-06): the schedule screen used to
     * send the whole business profile just to change this number, which silently put back an older business name,
     * bio or address if those had been edited elsewhere in the meantime.
     */
    @PatchMapping("/travel-buffer")
    public ApiResponse.Success<Void> updateTravelBuffer(
            @RequestParam int minutes,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (minutes < 0 || minutes > 60) {
            throw new com.aiwa.exception.BusinessException("provider.travel_buffer.invalid");
        }
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        provider.setTravelBufferMinutes(minutes);
        providerRepo.save(provider);
        return ApiResponse.Success.of("Travel buffer updated", null);
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }
}
