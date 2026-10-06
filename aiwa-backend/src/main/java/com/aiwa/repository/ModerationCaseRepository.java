package com.aiwa.repository;

import com.aiwa.entity.ModerationCase;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ModerationCaseRepository extends JpaRepository<ModerationCase, Long> {
    List<ModerationCase> findByStatusOrderByCreatedAtDesc(ModerationStatus status);
    List<ModerationCase> findByStatusAndTargetTypeOrderByCreatedAtDesc(ModerationStatus status, ModerationTargetType targetType);

    // DR-028: the admin queues are paged.
    Page<ModerationCase> findByStatusOrderByCreatedAtDesc(ModerationStatus status, Pageable pageable);

    Page<ModerationCase> findByStatusAndTargetTypeOrderByCreatedAtDesc(ModerationStatus status,
                                                                       ModerationTargetType targetType,
                                                                       Pageable pageable);

    // R5 follow-up: the three case queues, searched and paged on the server. "q" is a lower-case LIKE pattern from
    // com.aiwa.util.Searches ("%" = no search). A case whose target no longer exists is not listed (as before: the old
    // controllers skipped it after paging, which made a page shorter than its size and the total wrong).

    /** Photo moderation: matches the report reason or the provider's business name. A case whose photo is gone stays listed. */
    @Query(value = "SELECT c FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.GALLERY_IMAGE AND "
            + "(COALESCE(LOWER(c.reason), '') LIKE :q OR EXISTS (SELECT 1 FROM GalleryImage g JOIN g.provider gp WHERE g.id = c.targetId "
            + "AND LOWER(gp.businessName) LIKE :q)) ORDER BY c.createdAt DESC, c.id DESC",
            countQuery = "SELECT COUNT(c) FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.GALLERY_IMAGE AND "
                    + "(COALESCE(LOWER(c.reason), '') LIKE :q OR EXISTS (SELECT 1 FROM GalleryImage g JOIN g.provider gp WHERE g.id = c.targetId "
                    + "AND LOWER(gp.businessName) LIKE :q))")
    Page<ModerationCase> searchImages(@Param("status") ModerationStatus status, @Param("q") String q, Pageable pageable);

    /** Reported reviews: matches the reason, the review text, the author or the provider. */
    @Query(value = "SELECT c FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.REVIEW AND "
            + "EXISTS (SELECT 1 FROM Review r LEFT JOIN r.user ru LEFT JOIN r.provider rp WHERE r.id = c.targetId AND "
            + "(COALESCE(LOWER(c.reason), '') LIKE :q OR COALESCE(LOWER(r.comment), '') LIKE :q OR COALESCE(LOWER(ru.fullName), '') LIKE :q "
            + "OR COALESCE(LOWER(rp.businessName), '') LIKE :q)) ORDER BY c.createdAt DESC, c.id DESC",
            countQuery = "SELECT COUNT(c) FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.REVIEW AND "
                    + "EXISTS (SELECT 1 FROM Review r LEFT JOIN r.user ru LEFT JOIN r.provider rp WHERE r.id = c.targetId AND "
                    + "(COALESCE(LOWER(c.reason), '') LIKE :q OR COALESCE(LOWER(r.comment), '') LIKE :q OR COALESCE(LOWER(ru.fullName), '') LIKE :q "
                    + "OR COALESCE(LOWER(rp.businessName), '') LIKE :q))")
    Page<ModerationCase> searchReviews(@Param("status") ModerationStatus status, @Param("q") String q, Pageable pageable);

    /** Reported chat messages: matches the reason, the message, the sender or the booking number. */
    @Query(value = "SELECT c FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.CHAT_MESSAGE AND "
            + "EXISTS (SELECT 1 FROM ChatMessage m LEFT JOIN m.sender ms WHERE m.id = c.targetId AND "
            + "(COALESCE(LOWER(c.reason), '') LIKE :q OR COALESCE(LOWER(m.message), '') LIKE :q OR COALESCE(LOWER(ms.fullName), '') LIKE :q "
            + "OR CAST(m.booking.id AS string) LIKE :q)) ORDER BY c.createdAt DESC, c.id DESC",
            countQuery = "SELECT COUNT(c) FROM ModerationCase c WHERE c.status = :status AND c.targetType = com.aiwa.enums.ModerationTargetType.CHAT_MESSAGE AND "
                    + "EXISTS (SELECT 1 FROM ChatMessage m LEFT JOIN m.sender ms WHERE m.id = c.targetId AND "
                    + "(COALESCE(LOWER(c.reason), '') LIKE :q OR COALESCE(LOWER(m.message), '') LIKE :q OR COALESCE(LOWER(ms.fullName), '') LIKE :q "
                    + "OR CAST(m.booking.id AS string) LIKE :q))")
    Page<ModerationCase> searchChat(@Param("status") ModerationStatus status, @Param("q") String q, Pageable pageable);

    /** Every case of a status, filtered by the reason only (the unfiltered-by-type listing). */
    @Query(value = "SELECT c FROM ModerationCase c WHERE c.status = :status AND COALESCE(LOWER(c.reason), '') LIKE :q ORDER BY c.createdAt DESC, c.id DESC",
            countQuery = "SELECT COUNT(c) FROM ModerationCase c WHERE c.status = :status AND COALESCE(LOWER(c.reason), '') LIKE :q")
    Page<ModerationCase> searchByReason(@Param("status") ModerationStatus status, @Param("q") String q, Pageable pageable);

    boolean existsByStatusAndTargetTypeAndTargetId(ModerationStatus status, ModerationTargetType targetType,
                                                   Long targetId);
}
