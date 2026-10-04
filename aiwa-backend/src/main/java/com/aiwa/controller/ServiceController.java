package com.aiwa.controller;

import com.aiwa.dto.request.ServiceRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.ServiceManagementServiceImpl;
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
@Tag(name = "Services", description = "Service management for providers")
public class ServiceController {

    private final ServiceManagementServiceImpl serviceManagementService;
    private final UserRepository userRepo;

    @GetMapping("/providers/{providerId}/services")
    @Operation(summary = "List active services for a provider (public)")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.ServiceDto>>> list(
            @PathVariable Long providerId) {
        return ResponseEntity.ok(ApiResponse.Success.of(
                serviceManagementService.getByProvider(providerId)));
    }

    @PostMapping("/provider/services")
    @Operation(summary = "Add a service (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ServiceDto>> create(
            @Valid @RequestBody ServiceRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Service created",
                        serviceManagementService.create(resolveUserId(userDetails), request)));
    }

    @PutMapping("/provider/services/{serviceId}")
    @Operation(summary = "Update a service (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.ServiceDto>> update(
            @PathVariable Long serviceId,
            @Valid @RequestBody ServiceRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {

        return ResponseEntity.ok(ApiResponse.Success.of("Service updated",
                serviceManagementService.update(resolveUserId(userDetails), serviceId, request)));
    }

    @DeleteMapping("/provider/services/{serviceId}")
    @Operation(summary = "Delete (deactivate) a service (PROVIDER role)")
    public ResponseEntity<ApiResponse.Success<Void>> delete(
            @PathVariable Long serviceId,
            @AuthenticationPrincipal UserDetails userDetails) {

        serviceManagementService.delete(resolveUserId(userDetails), serviceId);
        return ResponseEntity.ok(ApiResponse.Success.of("Service deleted", null));
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }
}
