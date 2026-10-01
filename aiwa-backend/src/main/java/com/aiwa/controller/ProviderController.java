package com.aiwa.controller;

import com.aiwa.dto.request.ProviderProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.repository.UserRepository;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@Tag(name = "Providers", description = "Provider discovery and profile management")
public class ProviderController {

    private final com.aiwa.service.impl.ProviderServiceImpl providerService;
    private final com.aiwa.service.impl.WaitlistService waitlistService;
    private final UserRepository userRepo;

    // ── Public endpoints ──────────────────────────────────────────────────────

    @GetMapping("/providers/nearby")
    @Operation(summary = "Discover nearby providers (location-based) — sort: distance|rating|price")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderSummaryDto>>> getNearby(
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "10") double radiusKm,
            @RequestParam(required = false) ServiceCategory category,
            @RequestParam(defaultValue = "distance") String sort,
            @RequestParam(required = false) java.math.BigDecimal maxPrice,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                providerService.getNearby(lat, lng, radiusKm, category, sort, maxPrice, pageOf(page, size))));
    }

    @GetMapping("/providers/search")
    @Operation(summary = "Search providers by name")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderSummaryDto>>> search(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                providerService.search(q, pageOf(page, size))));
    }

    @GetMapping("/providers/{id}")
    @Operation(summary = "Get full provider profile with services and reviews "
            + "(the owner phone only for the owner, admins and customers with a live booking)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> getById(
            @PathVariable Long id,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                providerService.getById(id, lat, lng, callerId(userDetails),
                        userDetails != null && userDetails.getAuthorities().stream()
                                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority())))));
    }

    @PostMapping("/providers/waitlist")
    @Operation(summary = "\"Notify me when someone joins\" — alert me once when a provider in this "
            + "category (optionally near lat/lng) is approved")
    public ResponseEntity<ApiResponse.Success<Void>> joinWaitlist(
            @RequestParam(required = false) ServiceCategory category,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @AuthenticationPrincipal UserDetails userDetails) {
        com.aiwa.entity.User user = userRepo.findByLogin(userDetails.getUsername())
                .orElseThrow();
        waitlistService.join(user, category, lat, lng);
        return ResponseEntity.ok(ApiResponse.Success.of("We'll let you know when someone joins", null));
    }

    private static Pageable pageOf(int page, int size) {
        return PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 50)));
    }

    // ── Provider-only endpoints ───────────────────────────────────────────────

    @PostMapping("/provider/profile")
    @Operation(summary = "Create provider profile (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> createProfile(
            @Valid @RequestBody ProviderProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Profile created", providerService.createProfile(userId, request)));
    }

    @PutMapping("/provider/profile")
    @Operation(summary = "Update provider profile (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> updateProfile(
            @Valid @RequestBody ProviderProfileRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of("Profile updated", providerService.updateProfile(userId, request)));
    }

    @GetMapping("/provider/dashboard")
    @Operation(summary = "Get provider dashboard stats (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.DashboardDto>> getDashboard(
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of(providerService.getDashboard(userId)));
    }

    // ── helper ────────────────────────────────────────────────────────────────

    private Long callerId(UserDetails userDetails) {
        return userDetails == null ? null : resolveUserId(userDetails);
    }

    private Long resolveUserId(UserDetails userDetails) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(userDetails);
        if (id != null) return id;
        return userRepo.findByLogin(userDetails.getUsername())
                .map(User::getId)
                .orElseThrow();
    }
}
