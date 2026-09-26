package com.aiwa.controller;

import com.aiwa.dto.request.ProviderProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.ProviderService;
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

    private final ProviderService providerService;
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
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = PageRequest.of(page, size);
        return ResponseEntity.ok(ApiResponse.Success.of(
                providerService.getNearby(lat, lng, radiusKm, category, sort, pageable)));
    }

    @GetMapping("/providers/search")
    @Operation(summary = "Search providers by name")
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderSummaryDto>>> search(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        return ResponseEntity.ok(ApiResponse.Success.of(
                providerService.search(q, PageRequest.of(page, size))));
    }

    @GetMapping("/providers/{id}")
    @Operation(summary = "Get full provider profile with services and reviews")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> getById(
            @PathVariable Long id,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {

        return ResponseEntity.ok(ApiResponse.Success.of(providerService.getById(id, lat, lng)));
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

    private Long resolveUserId(UserDetails userDetails) {
        return userRepo.findByEmail(userDetails.getUsername())
                .or(() -> userRepo.findByPhone(userDetails.getUsername()))
                .map(User::getId)
                .orElseThrow();
    }
}
