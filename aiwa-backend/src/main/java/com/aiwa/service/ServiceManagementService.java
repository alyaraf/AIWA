package com.aiwa.service;

import com.aiwa.dto.request.ServiceRequest;
import com.aiwa.dto.response.ApiResponse;

import java.util.List;

public interface ServiceManagementService {
    ApiResponse.ServiceDto create(Long userId, ServiceRequest request);
    ApiResponse.ServiceDto update(Long userId, Long serviceId, ServiceRequest request);
    void delete(Long userId, Long serviceId);
    List<ApiResponse.ServiceDto> getByProvider(Long providerId);
}
