package com.aiwa.service;

import com.aiwa.dto.request.ProviderProfileRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.enums.ServiceCategory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface ProviderService {
    ApiResponse.ProviderDetailDto createProfile(Long userId, ProviderProfileRequest request);
    ApiResponse.ProviderDetailDto updateProfile(Long userId, ProviderProfileRequest request);
    ApiResponse.ProviderDetailDto getById(Long providerId, Double userLat, Double userLng);
    Page<ApiResponse.ProviderSummaryDto> getNearby(double lat, double lng, double radiusKm,
                                                    ServiceCategory category, String sort, Pageable pageable);
    Page<ApiResponse.ProviderSummaryDto> search(String query, Pageable pageable);
    ApiResponse.DashboardDto getDashboard(Long userId);
}
