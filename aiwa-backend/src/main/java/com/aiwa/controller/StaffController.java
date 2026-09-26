package com.aiwa.controller;

import com.aiwa.dto.request.StaffMemberRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
public class StaffController {

    private final ProviderProfileRepository providerRepo;
    private final StaffMemberRepository staffRepo;
    private final UserRepository userRepo;

    @GetMapping("/providers/{providerId}/staff")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.StaffMemberDto>>> publicStaff(
            @PathVariable Long providerId) {
        return ResponseEntity.ok(ApiResponse.Success.of(staffRepo
                .findByProviderIdAndActiveTrueOrderByFullNameAsc(providerId)
                .stream().map(this::toDto).toList()));
    }

    @PostMapping("/provider/staff")
    @PreAuthorize("hasRole('PROVIDER')")
    public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> add(
            @Valid @RequestBody StaffMemberRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        StaffMember staff = StaffMember.builder()
                .provider(provider)
                .fullName(request.getFullName())
                .title(request.getTitle())
                .phone(request.getPhone())
                .skills(request.getSkills())
                .active(request.getActive() == null || request.getActive())
                .build();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Staff member added", toDto(staffRepo.save(staff))));
    }

    @PutMapping("/provider/staff/{id}")
    @PreAuthorize("hasRole('PROVIDER')")
    public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody StaffMemberRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        StaffMember staff = staffRepo.findByIdAndProviderId(id, provider.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Staff member", id));
        staff.setFullName(request.getFullName());
        staff.setTitle(request.getTitle());
        staff.setPhone(request.getPhone());
        if (request.getSkills() != null) staff.setSkills(request.getSkills());
        if (request.getActive() != null) staff.setActive(request.getActive());
        return ResponseEntity.ok(ApiResponse.Success.of("Staff member updated", toDto(staffRepo.save(staff))));
    }

    private Long resolveUserId(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .map(User::getId).orElseThrow();
    }

    private ApiResponse.StaffMemberDto toDto(StaffMember s) {
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
