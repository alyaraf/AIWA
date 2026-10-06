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

    /** Public listing: customer reviews of the provider only, excluding admin-hidden ones. */
    Page<Review> findByProviderIdAndDirectionAndHiddenFalseOrderByCreatedAtDesc(
            Long providerId, ReviewDirection direction, Pageable pageable);

    Page<Review> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /** R6 follow-up: the reviews of one moderation page, each with its author and provider, in a single query. */
    @Query("SELECT r FROM Review r LEFT JOIN FETCH r.user u LEFT JOIN FETCH u.providerProfile LEFT JOIN FETCH r.provider WHERE r.id IN :ids")
    java.util.List<Review> findAllWithPeopleByIdIn(@Param("ids") java.util.Collection<Long> ids);

    /**
     * Admin search (R4 follow-up): comment, customer name or provider business name ("%" = no search), optionally only
     * ratings up to {@code maxRating} (5 = every review; 2 = the "Low rating" view).
     */
    // The inverse one-to-one User.providerProfile is read with a query per user unless it is part of the graph.
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user", "user.providerProfile", "provider", "provider.user", "provider.user.providerProfile", "booking"})
    @Query(value = "SELECT r FROM Review r LEFT JOIN r.user u LEFT JOIN r.provider p WHERE r.rating <= :maxRating AND "
            + "(COALESCE(LOWER(r.comment), '') LIKE :q OR LOWER(u.fullName) LIKE :q OR LOWER(p.businessName) LIKE :q) ORDER BY r.createdAt DESC",
            countQuery = "SELECT COUNT(r) FROM Review r LEFT JOIN r.user u LEFT JOIN r.provider p WHERE r.rating <= :maxRating AND "
                    + "(COALESCE(LOWER(r.comment), '') LIKE :q OR LOWER(u.fullName) LIKE :q OR LOWER(p.businessName) LIKE :q)")
    Page<Review> searchAdmin(@Param("q") String q, @Param("maxRating") int maxRating, Pageable pageable);

    boolean existsByBookingIdAndDirection(Long bookingId, ReviewDirection direction);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.provider.id = :providerId AND r.direction = com.aiwa.enums.ReviewDirection.CUSTOMER_TO_PROVIDER AND r.hidden = false")
    Double calculateAverageRating(@Param("providerId") Long providerId);

    @Query("SELECT COUNT(r) FROM Review r WHERE r.provider.id = :providerId AND r.direction = com.aiwa.enums.ReviewDirection.CUSTOMER_TO_PROVIDER AND r.hidden = false")
    long countVisibleForProvider(@Param("providerId") Long providerId);
}

