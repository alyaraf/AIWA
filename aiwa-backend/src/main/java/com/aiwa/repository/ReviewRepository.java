package com.aiwa.repository;

import com.aiwa.entity.Review;
import com.aiwa.enums.ReviewDirection;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface ReviewRepository extends JpaRepository<Review, Long> {

    Page<Review> findByProviderIdOrderByCreatedAtDesc(Long providerId, Pageable pageable);

    Page<Review> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    // Public listing excludes admin-hidden reviews.
    Page<Review> findByProviderIdAndHiddenFalseOrderByCreatedAtDesc(Long providerId, Pageable pageable);

    Page<Review> findAllByOrderByCreatedAtDesc(Pageable pageable);

    boolean existsByBookingIdAndDirection(Long bookingId, ReviewDirection direction);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.provider.id = :providerId AND r.direction = com.aiwa.enums.ReviewDirection.CUSTOMER_TO_PROVIDER AND r.hidden = false")
    Double calculateAverageRating(@Param("providerId") Long providerId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.provider.id = :providerId AND r.direction = com.aiwa.enums.ReviewDirection.CUSTOMER_TO_PROVIDER AND r.hidden = false")
    long countVisibleForProvider(@Param("providerId") Long providerId);
}

