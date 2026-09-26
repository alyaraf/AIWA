package com.aiwa.service.impl;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.User;
import com.aiwa.enums.ReviewDirection;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ReviewModerationTest {

    private final ReviewRepository reviewRepo = mock(ReviewRepository.class);
    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);

    private final ReviewServiceImpl service = new ReviewServiceImpl(reviewRepo, bookingRepo, userRepo, providerRepo);

    @Test
    void hidingReviewRecomputesProviderRating() {
        ProviderProfile provider = ProviderProfile.builder().id(7L).averageRating(4.8).totalReviews(10).build();
        Review review = Review.builder().id(3L).provider(provider).rating(1)
                .user(User.builder().id(5L).fullName("Reviewer").build())
                .direction(ReviewDirection.CUSTOMER_TO_PROVIDER).hidden(false).build();
        when(reviewRepo.findById(3L)).thenReturn(Optional.of(review));
        when(reviewRepo.save(any(Review.class))).thenAnswer(inv -> inv.getArgument(0));
        when(reviewRepo.calculateAverageRating(7L)).thenReturn(4.9);
        when(reviewRepo.countVisibleForProvider(7L)).thenReturn(9L);

        var dto = service.setVisibility(3L, true);

        assertThat(review.isHidden()).isTrue();
        assertThat(dto.isHidden()).isTrue();
        assertThat(provider.getAverageRating()).isEqualTo(4.9);
        assertThat(provider.getTotalReviews()).isEqualTo(9);
        verify(providerRepo).save(provider);
    }

    @Test
    void unknownReviewThrows() {
        when(reviewRepo.findById(99L)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.setVisibility(99L, true))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}
