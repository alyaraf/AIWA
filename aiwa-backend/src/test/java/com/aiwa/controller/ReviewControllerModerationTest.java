package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ModerationCase;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.User;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import com.aiwa.repository.ModerationCaseRepository;
import com.aiwa.repository.ReviewRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.ReviewServiceImpl;
import com.aiwa.service.impl.AuditService;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class ReviewControllerModerationTest {

    private final com.aiwa.service.impl.ReviewServiceImpl reviewService = mock(com.aiwa.service.impl.ReviewServiceImpl.class);
    private final UserRepository userRepo = mock(UserRepository.class);
    private final AuditService auditService = mock(AuditService.class);
    private final ModerationCaseRepository moderationRepo = mock(ModerationCaseRepository.class);
    private final ReviewRepository reviewRepo = mock(ReviewRepository.class);

    private final ReviewController controller =
            new ReviewController(reviewService, userRepo, auditService, moderationRepo, reviewRepo,
                    mock(com.aiwa.service.impl.ProviderServiceImpl.class));

    private ModerationCase openCase(long id, long reviewId) {
        return ModerationCase.builder()
                .id(id).targetId(reviewId)
                .targetType(ModerationTargetType.REVIEW)
                .reason("Abusive language")
                .status(ModerationStatus.OPEN)
                .build();
    }

    @Test
    void reportedReviewsJoinsCaseWithReview() {
        ModerationCase c = openCase(1L, 3L);
        Review review = Review.builder().id(3L).rating(2).comment("bad")
                .user(User.builder().id(5L).fullName("Karim").build())
                .provider(ProviderProfile.builder().id(9L).businessName("Omar Barber").build())
                .hidden(false).build();
        when(moderationRepo.searchReviews(eq(ModerationStatus.OPEN), eq("%"), any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(c)));
        when(reviewRepo.findAllWithPeopleByIdIn(any())).thenReturn(List.of(review));

        var body = controller.reportedReviews(null, 0, 200).getBody();
        assertThat(body).isNotNull();
        List<ApiResponse.ReviewModerationDto> rows = body.getData().getContent();
        assertThat(rows).hasSize(1);
        assertThat(rows.get(0).getModerationCaseId()).isEqualTo(1L);
        assertThat(rows.get(0).getReviewId()).isEqualTo(3L);
        assertThat(rows.get(0).getAuthorName()).isEqualTo("Karim");
        assertThat(rows.get(0).getProviderName()).isEqualTo("Omar Barber");
        assertThat(rows.get(0).getReason()).isEqualTo("Abusive language");
    }

    @Test
    void reportedReviewsSkipsMissingReviews() {
        when(moderationRepo.searchReviews(eq(ModerationStatus.OPEN), eq("%"), any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(openCase(1L, 404L))));
        when(reviewRepo.findAllWithPeopleByIdIn(any())).thenReturn(List.of());

        assertThat(controller.reportedReviews(null, 0, 200).getBody().getData().getContent()).isEmpty();
    }

    @Test
    void resolveRemoveHidesReviewAndActionsCase() {
        ModerationCase c = openCase(1L, 3L);
        when(moderationRepo.findById(1L)).thenReturn(Optional.of(c));

        controller.resolveReported(1L, "REMOVE");

        verify(reviewService).setVisibility(3L, true);
        assertThat(c.getStatus()).isEqualTo(ModerationStatus.ACTIONED);
        verify(moderationRepo).save(c);
    }

    @Test
    void resolveKeepDismissesWithoutHiding() {
        ModerationCase c = openCase(2L, 8L);
        when(moderationRepo.findById(2L)).thenReturn(Optional.of(c));

        controller.resolveReported(2L, "keep");

        verify(reviewService, never()).setVisibility(eq(8L), org.mockito.ArgumentMatchers.anyBoolean());
        assertThat(c.getStatus()).isEqualTo(ModerationStatus.DISMISSED);
    }
}
