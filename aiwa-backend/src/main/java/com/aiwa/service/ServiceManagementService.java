package com.aiwa.service;

import com.aiwa.dto.request.ServiceRequest;
import com.aiwa.dto.response.ApiResponse;

import java.util.List;

// ponytail: one implementation (ServiceManagementServiceImpl), inline into a concrete @Service when touched; keep only if a second impl appears
public interface ServiceManagementService {
    ApiResponse.ServiceDto create(Long userId, ServiceRequest request);
    ApiResponse.ServiceDto update(Long userId, Long serviceId, ServiceRequest request);
    void delete(Long userId, Long serviceId);
    List<ApiResponse.ServiceDto> getByProvider(Long providerId);
}
