package com.aiwa.service.impl;

import com.aiwa.dto.request.ReviewRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ReviewDirection;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.ReviewService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ReviewServiceImpl implements ReviewService {

    private final ReviewRepository reviewRepo;
    private final BookingRepository bookingRepo;
    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;

    @Override
    @Transactional
    public ApiResponse.ReviewDto create(Long userId, ReviewRequest req) {
        ReviewDirection direction = req.getDirection() != null
                ? req.getDirection() : ReviewDirection.CUSTOMER_TO_PROVIDER;
        if (reviewRepo.existsByBookingIdAndDirection(req.getBookingId(), direction)) {
            throw new BusinessException("review.error.already_reviewed");
        }

        Booking booking = bookingRepo.findById(req.getBookingId())
                .orElseThrow(() -> new ResourceNotFoundException("Booking", req.getBookingId()));

        boolean customerReview = direction == ReviewDirection.CUSTOMER_TO_PROVIDER
                || direction == ReviewDirection.SAFETY;
        boolean isCustomer = booking.getCustomer().getId().equals(userId);
        boolean isProvider = booking.getProvider().getUser().getId().equals(userId);
        if ((customerReview && !isCustomer) || (direction == ReviewDirection.PROVIDER_TO_CUSTOMER && !isProvider)) {
            throw new BusinessException("review.error.not_your_booking");
        }
        if (booking.getStatus() != BookingStatus.COMPLETED) {
            throw new BusinessException("review.error.not_completed");
        }

        User user = userRepo.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", userId));

        Review review = Review.builder()
                .user(user)
                .provider(booking.getProvider())
                .booking(booking)
                .direction(direction)
                .rating(req.getRating())
                .comment(req.getComment())
                .quickTags(req.getQuickTags() != null ? req.getQuickTags() : new java.util.ArrayList<>())
                .build();

        reviewRepo.save(review);

        if (direction == ReviewDirection.CUSTOMER_TO_PROVIDER) {
            ProviderProfile provider = booking.getProvider();
            Double avg = reviewRepo.calculateAverageRating(provider.getId());
            provider.setAverageRating(avg != null ? Math.round(avg * 10.0) / 10.0 : 0.0);
            provider.setTotalReviews(provider.getTotalReviews() + 1);
            providerRepo.save(provider);
        }

        return toDto(review);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<ApiResponse.ReviewDto> getByProvider(Long providerId, Pageable pageable) {
        return reviewRepo.findByProviderIdAndHiddenFalseOrderByCreatedAtDesc(providerId, pageable)
                .map(this::toDto);
    }

    /** Admin moderation: hide/unhide a review and recompute the provider's rating. */
    @Override
    @Transactional
    public ApiResponse.ReviewDto setVisibility(Long reviewId, boolean hidden) {
        Review review = reviewRepo.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review", reviewId));
        review.setHidden(hidden);
        reviewRepo.save(review);

        if (review.getDirection() == ReviewDirection.CUSTOMER_TO_PROVIDER) {
            ProviderProfile provider = review.getProvider();
            Double avg = reviewRepo.calculateAverageRating(provider.getId());
            provider.setAverageRating(avg != null ? Math.round(avg * 10.0) / 10.0 : 0.0);
            provider.setTotalReviews((int) reviewRepo.countVisibleForProvider(provider.getId()));
            providerRepo.save(provider);
        }
        return toDto(review);
    }

    private ApiResponse.ReviewDto toDto(Review r) {
        return ApiResponse.ReviewDto.builder()
                .id(r.getId())
                .user(ApiResponse.UserDto.builder()
                        .id(r.getUser().getId())
                        .fullName(r.getUser().getFullName())
                        .profileImageUrl(r.getUser().getProfileImageUrl())
                        .build())
                .rating(r.getRating())
                .comment(r.getComment())
                .quickTags(r.getQuickTags())
                .direction(r.getDirection())
                .hidden(r.isHidden())
                .createdAt(r.getCreatedAt())
                .build();
    }
}
