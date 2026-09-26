package com.aiwa.service.impl;

import com.aiwa.dto.request.AvailabilityRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.Availability;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.StaffMember;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.StaffMemberRepository;
import com.aiwa.service.AvailabilityService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AvailabilityServiceImpl implements AvailabilityService {

    private final AvailabilityRepository availabilityRepo;
    private final ProviderProfileRepository providerRepo;
    private final StaffMemberRepository staffRepo;

    @Override
    @Transactional
    public ApiResponse.AvailabilityDto upsert(Long userId, AvailabilityRequest req) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        if (req.getEndTime().isBefore(req.getStartTime()) || req.getEndTime().equals(req.getStartTime())) {
            throw new BusinessException("availability.error.invalid_times");
        }

        // Optional staff scoping (shop providers): validate the staff belongs here.
        StaffMember staff = null;
        Availability avail;
        if (req.getStaffMemberId() != null) {
            staff = staffRepo.findByIdAndProviderId(req.getStaffMemberId(), profile.getId())
                    .orElseThrow(() -> new BusinessException("booking.error.staff_wrong_provider"));
            avail = availabilityRepo
                    .findByProviderIdAndStaffMemberIdAndDayOfWeek(profile.getId(), staff.getId(), req.getDayOfWeek())
                    .orElse(Availability.builder().provider(profile).staffMember(staff).build());
        } else {
            avail = availabilityRepo
                    .findByProviderIdAndStaffMemberIsNullAndDayOfWeek(profile.getId(), req.getDayOfWeek())
                    .orElse(Availability.builder().provider(profile).build());
        }

        avail.setStaffMember(staff);
        avail.setDayOfWeek(req.getDayOfWeek());
        avail.setStartTime(req.getStartTime());
        avail.setEndTime(req.getEndTime());
        avail.setSlotDurationMinutes(req.getSlotDurationMinutes());
        avail.setAvailable(req.isAvailable());

        return toDto(availabilityRepo.save(avail));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ApiResponse.AvailabilityDto> getByProvider(Long providerId) {
        return availabilityRepo.findByProviderIdAndAvailableTrue(providerId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public void delete(Long userId, Long availabilityId) {
        Availability avail = availabilityRepo.findById(availabilityId)
                .orElseThrow(() -> new ResourceNotFoundException("Availability", availabilityId));

        if (!avail.getProvider().getUser().getId().equals(userId)) {
            throw new BusinessException("error.not_authorized");
        }
        availabilityRepo.delete(avail);
    }

    private ApiResponse.AvailabilityDto toDto(Availability a) {
        return ApiResponse.AvailabilityDto.builder()
                .id(a.getId())
                .staffMemberId(a.getStaffMember() != null ? a.getStaffMember().getId() : null)
                .dayOfWeek(a.getDayOfWeek())
                .startTime(a.getStartTime())
                .endTime(a.getEndTime())
                .slotDurationMinutes(a.getSlotDurationMinutes())
                .available(a.isAvailable())
                .build();
    }
}
