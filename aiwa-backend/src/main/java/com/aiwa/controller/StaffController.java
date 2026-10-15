package com.aiwa.controller;

import com.aiwa.dto.request.StaffMemberRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.HashSet;
import java.util.List;

@RestController
@RequiredArgsConstructor
public class StaffController {

    private final ProviderProfileRepository providerRepo;
    private final StaffMemberRepository staffRepo;
    private final ServiceRepository serviceRepo;
    private final UserRepository userRepo;
    private final com.aiwa.service.impl.ProviderServiceImpl providerService;

    /**
     * Public staff picker. Staff phone numbers are NOT included — this endpoint
     * needs no authentication, and it used to publish every staff member's
     * personal number. AP-05: an unlisted provider's staff only to its owner and admins.
     */
    @GetMapping("/providers/{providerId}/staff")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.StaffMemberDto>>> publicStaff(
            @PathVariable Long providerId,
            @RequestParam(required = false) Long serviceId,
            @AuthenticationPrincipal UserDetails userDetails) {
        providerService.requireVisibleListing(providerId, userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of(staffRepo
                .findByProviderIdAndActiveTrueOrderByFullNameAsc(providerId)
                .stream()
                // With a service chosen, only the people who perform it.
                .filter(s -> serviceId == null || s.getServices().isEmpty()
                        || s.getServices().stream().anyMatch(sv -> sv.getId().equals(serviceId)))
                .map(s -> toDto(s, false)).toList()));
    }

    @PostMapping("/provider/staff")
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> add(
            @Valid @RequestBody StaffMemberRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        StaffMember staff = StaffMember.builder()
                .provider(provider)
                .fullName(request.getFullName().trim())
                .title(request.getTitle())
                .phone(request.getPhone())
                .skills(request.getSkills())
                .active(request.getActive() == null || request.getActive())
                .build();
        if (request.getServiceIds() != null) {
            staff.setServices(ownServices(request.getServiceIds(), provider.getId()));
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Staff member added", toDto(staffRepo.save(staff), true)));
    }

    @PutMapping("/provider/staff/{id}")
    @PreAuthorize("hasRole('PROVIDER')")
    @Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> update(
            @PathVariable Long id,
            @Valid @RequestBody StaffMemberRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        ProviderProfile provider = providerRepo.findByUserId(resolveUserId(userDetails))
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));
        StaffMember staff = staffRepo.findByIdAndProviderId(id, provider.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Staff member", id));
        staff.setFullName(request.getFullName().trim());
        staff.setTitle(request.getTitle());
        staff.setPhone(request.getPhone());
        if (request.getSkills() != null) staff.setSkills(request.getSkills());
        if (request.getActive() != null) staff.setActive(request.getActive());
        if (request.getServiceIds() != null) {
            staff.setServices(ownServices(request.getServiceIds(), provider.getId()));
        }
        return ResponseEntity.ok(ApiResponse.Success.of("Staff member updated", toDto(staffRepo.save(staff), true)));
    }

    /** Only the provider's own services may be linked (no linking another business's service ids). */
    private java.util.Set<com.aiwa.entity.Service> ownServices(List<Long> ids, Long providerId) {
        if (ids.isEmpty()) return new HashSet<>();
        List<com.aiwa.entity.Service> found = serviceRepo.findByIdInAndProviderId(ids, providerId);
        if (found.size() != new HashSet<>(ids).size()) {
            throw new BusinessException("staff.error.unknown_service");
        }
        return new HashSet<>(found);
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return userRepo.findByLogin(ud.getUsername())
                .map(User::getId).orElseThrow();
    }

    private ApiResponse.StaffMemberDto toDto(StaffMember s, boolean withPhone) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
                .phone(withPhone ? s.getPhone() : null)
                .skills(s.getSkills())
                .active(s.isActive())
                .serviceIds(s.getServices().stream().map(com.aiwa.entity.Service::getId).sorted().toList())
                .build();
    }
}
