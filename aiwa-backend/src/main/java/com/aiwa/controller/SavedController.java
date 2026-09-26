package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.ProviderServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/users/me/saved")
@RequiredArgsConstructor
@Tag(name = "Saved Providers", description = "Customer saved / favourited providers (GAP 2)")
public class SavedController {

    private final SavedProviderRepository savedRepo;
    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;
    private final ProviderServiceImpl providerServiceImpl;

    @GetMapping
    @Operation(summary = "List all saved providers for the current customer")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.ProviderSummaryDto>>> list(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {

        Long userId = resolveUserId(userDetails);
        List<ApiResponse.ProviderSummaryDto> dtos = savedRepo
                .findByUserIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(sp -> providerServiceImpl.toSummaryDto(sp.getProvider(), lat, lng))
                .collect(Collectors.toList());

        return ResponseEntity.ok(ApiResponse.Success.of(dtos));
    }

    @PostMapping("/{providerId}")
    @Operation(summary = "Save (heart) a provider")
    public ResponseEntity<ApiResponse.Success<Void>> save(
            @PathVariable Long providerId,
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);

        if (savedRepo.existsByUserIdAndProviderId(userId, providerId)) {
            throw new BusinessException("saved.error.already_saved");
        }

        User user = userRepo.findById(userId).orElseThrow();
        ProviderProfile provider = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));

        savedRepo.save(SavedProvider.builder().user(user).provider(provider).build());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Provider saved", null));
    }

    @DeleteMapping("/{providerId}")
    @Operation(summary = "Unsave (un-heart) a provider")
    public ResponseEntity<ApiResponse.Success<Void>> unsave(
            @PathVariable Long providerId,
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);
        savedRepo.deleteByUserIdAndProviderId(userId, providerId);
        return ResponseEntity.ok(ApiResponse.Success.of("Provider removed from saved", null));
    }

    @GetMapping("/{providerId}/check")
    @Operation(summary = "Check if a provider is saved by current user — returns boolean")
    public ResponseEntity<ApiResponse.Success<Boolean>> check(
            @PathVariable Long providerId,
            @AuthenticationPrincipal UserDetails userDetails) {

        Long userId = resolveUserId(userDetails);
        boolean saved = savedRepo.existsByUserIdAndProviderId(userId, providerId);
        return ResponseEntity.ok(ApiResponse.Success.of(saved));
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
