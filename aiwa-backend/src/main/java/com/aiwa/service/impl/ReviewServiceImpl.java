package com.aiwa.service.impl;

import com.aiwa.dto.request.ReviewRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.ReviewDirection;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ForbiddenException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ReviewServiceImpl {

    static final int MAX_TAGS = 10;
    static final int MAX_TAG_LENGTH = 40;

    private final ReviewRepository reviewRepo;
    private final BookingRepository bookingRepo;
    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;

    /** Optional so the unit tests can construct the service without it. */
    private NotificationServiceImpl notificationService;

    @Autowired(required = false)
    void setNotificationService(NotificationServiceImpl notificationService) {
        this.notificationService = notificationService;
    }

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
            throw new ForbiddenException("review.error.not_your_booking");
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
                .comment(req.getComment() == null || req.getComment().isBlank() ? null : req.getComment().trim())
                .quickTags(cleanTags(req.getQuickTags()))
                .build();

        reviewRepo.save(review);

        if (direction == ReviewDirection.CUSTOMER_TO_PROVIDER) {
            recomputeRating(booking.getProvider());
            if (notificationService != null) {
                notificationService.send(booking.getProvider().getUser().getId(), NotificationType.REVIEW_RECEIVED,
                        "New " + req.getRating() + "★ review", "تقييم جديد " + req.getRating() + "★",
                        user.getFullName() + " reviewed " + booking.getService().getName() + ".",
                        user.getFullName() + " قيّم " + booking.getService().getName() + ".",
                        booking.getId(), booking.getProvider().getId());
            }
        }

        return toDto(review);
    }

    /**
     * Public provider reviews: only what customers wrote about the provider.
     * Before, this returned every review on the provider — including the
     * provider's own ratings OF their customers and SAFETY reports — on the
     * provider's public profile.
     */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ReviewDto> getByProvider(Long providerId, Pageable pageable) {
        return reviewRepo.findByProviderIdAndDirectionAndHiddenFalseOrderByCreatedAtDesc(
                        providerId, ReviewDirection.CUSTOMER_TO_PROVIDER, pageable)
                .map(this::toDto);
    }

    /** Reviews the caller has written (the customer profile "Reviews" tile uses totalElements). */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ReviewDto> getMine(Long userId, Pageable pageable) {
        return reviewRepo.findByUserIdOrderByCreatedAtDesc(userId, pageable).map(this::toDto);
    }

    /** BE-18: the provider answers a customer review publicly (one reply; sending again edits it). */
    @Transactional
    public ApiResponse.ReviewDto reply(Long providerUserId, Long reviewId, String text) {
        Review review = reviewRepo.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review", reviewId));
        if (!review.getProvider().getUser().getId().equals(providerUserId)) {
            throw new ForbiddenException("error.access_denied");
        }
        if (review.getDirection() != ReviewDirection.CUSTOMER_TO_PROVIDER) {
            throw new BusinessException("review.error.reply_customer_reviews_only");
        }
        String reply = text == null ? "" : text.trim();
        if (reply.isEmpty()) throw new BusinessException("review.error.reply_empty");
        if (reply.length() > 1000) throw new BusinessException("review.error.reply_too_long");

        boolean first = review.getReply() == null;
        review.setReply(reply);
        review.setRepliedAt(LocalDateTime.now());
        reviewRepo.save(review);

        if (first && notificationService != null) {
            notificationService.send(review.getUser().getId(), NotificationType.REVIEW_REPLY,
                    review.getProvider().getBusinessName() + " replied to your review",
                    "رد " + review.getProvider().getBusinessName() + " على تقييمك",
                    reply.length() > 140 ? reply.substring(0, 140) + "…" : reply,
                    reply.length() > 140 ? reply.substring(0, 140) + "…" : reply,
                    review.getBooking() != null ? review.getBooking().getId() : null,
                    review.getProvider().getId());
        }
        return toDto(review);
    }

    /** Admin moderation: hide/unhide a review and recompute the provider's rating. */
    @Transactional
    public ApiResponse.ReviewDto setVisibility(Long reviewId, boolean hidden) {
        Review review = reviewRepo.findById(reviewId)
                .orElseThrow(() -> new ResourceNotFoundException("Review", reviewId));
        review.setHidden(hidden);
        reviewRepo.save(review);

        if (review.getDirection() == ReviewDirection.CUSTOMER_TO_PROVIDER) {
            recomputeRating(review.getProvider());
        }
        return toDto(review);
    }

    /** Average and count both come from the visible customer reviews, so they always agree. */
    private void recomputeRating(ProviderProfile provider) {
        Double avg = reviewRepo.calculateAverageRating(provider.getId());
        provider.setAverageRating(avg != null ? Math.round(avg * 10.0) / 10.0 : 0.0);
        provider.setTotalReviews((int) reviewRepo.countVisibleForProvider(provider.getId()));
        providerRepo.save(provider);
    }

    private static List<String> cleanTags(List<String> tags) {
        List<String> out = new ArrayList<>();
        if (tags == null) return out;
        for (String t : tags) {
            if (t == null || t.isBlank()) continue;
            String tag = t.trim();
            if (tag.length() > MAX_TAG_LENGTH) tag = tag.substring(0, MAX_TAG_LENGTH);
            if (!out.contains(tag)) out.add(tag);
            if (out.size() == MAX_TAGS) break;
        }
        return out;
    }

    private ApiResponse.ReviewDto toDto(Review r) {
        Booking b = r.getBooking();
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
                .bookingId(b != null ? b.getId() : null)
                .serviceName(b != null && b.getService() != null ? b.getService().getName() : null)
                .reply(r.getReply())
                .repliedAt(r.getRepliedAt())
                .createdAt(r.getCreatedAt())
                .build();
    }
}
