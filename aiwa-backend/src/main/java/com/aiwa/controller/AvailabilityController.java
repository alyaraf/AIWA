package com.aiwa.controller;

import com.aiwa.dto.request.AvailabilityRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.AvailabilityService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@Tag(name = "Availability", description = "Manage provider working hours and slots")
public class AvailabilityController {

    private final AvailabilityService availabilityService;
    private final UserRepository userRepo;

    @GetMapping("/providers/{providerId}/availability")
    @Operation(summary = "Get a provider's working hours (public)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.AvailabilityDto>>> get(
            @PathVariable Long providerId) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                availabilityService.getByProvider(providerId)));
    }

    @PostMapping("/provider/availability")
    @Operation(summary = "Set/update availability for a day of week (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AvailabilityDto>> upsert(
            @Valid @RequestBody AvailabilityRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Availability saved",
                        availabilityService.upsert(resolveUserId(userDetails), request)));
    }

    @DeleteMapping("/provider/availability/{id}")
    @Operation(summary = "Remove an availability entry (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<Void>> delete(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {

        availabilityService.delete(resolveUserId(userDetails), id);
        return ResponseEntity.ok(ApiResponse.Success.of("Availability removed", null));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }
}
