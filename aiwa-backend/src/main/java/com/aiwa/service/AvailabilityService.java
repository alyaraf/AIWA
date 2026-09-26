package com.aiwa.service;

import com.aiwa.dto.request.AvailabilityRequest;
import com.aiwa.dto.response.ApiResponse;

import java.util.List;

public interface AvailabilityService {
    ApiResponse.AvailabilityDto upsert(Long userId, AvailabilityRequest request);
    List<ApiResponse.AvailabilityDto> getByProvider(Long providerId);
    void delete(Long userId, Long availabilityId);
}
