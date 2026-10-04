package com.aiwa.service.impl;

import com.aiwa.dto.request.ServiceRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.enums.PricingType;
import com.aiwa.entity.Service;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@org.springframework.stereotype.Service
@RequiredArgsConstructor
public class ServiceManagementServiceImpl {

    private final ServiceRepository serviceRepo;
    private final ProviderProfileRepository providerRepo;

    @Transactional
    public ApiResponse.ServiceDto create(Long userId, ServiceRequest req) {
        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        Service service = Service.builder()
                .provider(profile)
                .name(req.getName())
                .description(req.getDescription())
                .price(req.getPrice())
                .durationMinutes(req.getDurationMinutes())
                .category(req.getCategory())
                .pricingType(req.getPricingType() != null ? req.getPricingType() : PricingType.FIXED)
                .transportIncluded(req.isTransportIncluded())
                .active(true)
                .build();

        return toDto(serviceRepo.save(service));
    }

    @Transactional
    public ApiResponse.ServiceDto update(Long userId, Long serviceId, ServiceRequest req) {
        Service service = serviceRepo.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));

        if (!service.getProvider().getUser().getId().equals(userId)) {
            throw new BusinessException("service.unauthorized");
        }

        service.setName(req.getName());
        service.setDescription(req.getDescription());
        service.setPrice(req.getPrice());
        service.setDurationMinutes(req.getDurationMinutes());
        service.setCategory(req.getCategory());
        if (req.getPricingType() != null) service.setPricingType(req.getPricingType());
        service.setTransportIncluded(req.isTransportIncluded());

        return toDto(serviceRepo.save(service));
    }

    @Transactional
    public void delete(Long userId, Long serviceId) {
        Service service = serviceRepo.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));

        if (!service.getProvider().getUser().getId().equals(userId)) {
            throw new BusinessException("service.unauthorized");
        }
        // soft delete
        service.setActive(false);
        serviceRepo.save(service);
    }

    @Transactional(readOnly = true)
    public List<ApiResponse.ServiceDto> getByProvider(Long providerId) {
        return serviceRepo.findByProviderIdAndActiveTrue(providerId)
                .stream().map(this::toDto).collect(Collectors.toList());
    }

    private ApiResponse.ServiceDto toDto(com.aiwa.entity.Service s) {
        return ApiResponse.ServiceDto.builder()
                .id(s.getId())
                .name(s.getName())
                .description(s.getDescription())
                .price(s.getPrice())
                .durationMinutes(s.getDurationMinutes())
                .category(s.getCategory())
                .pricingType(s.getPricingType())
                .transportIncluded(s.isTransportIncluded())
                .active(s.isActive())
                .build();
    }
}
