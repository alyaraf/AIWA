package com.aiwa.service;

import com.aiwa.dto.request.ReviewRequest;
import com.aiwa.dto.response.ApiResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

// ponytail: one implementation (ReviewServiceImpl), inline into a concrete @Service when touched; keep only if a second impl appears
public interface ReviewService {
    ApiResponse.ReviewDto create(Long userId, ReviewRequest request);
    Page<ApiResponse.ReviewDto> getByProvider(Long providerId, Pageable pageable);
    ApiResponse.ReviewDto setVisibility(Long reviewId, boolean hidden);
}
