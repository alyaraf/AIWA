package com.aiwa.repository;

import com.aiwa.entity.Complaint;
import com.aiwa.enums.ComplaintStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ComplaintRepository extends JpaRepository<Complaint, Long> {
    Page<Complaint> findByReporterIdOrderByCreatedAtDesc(Long reporterId, Pageable pageable);

    /** The user's own reports, without internal admin flags (M-2). A null category is a normal report. */
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT c FROM Complaint c WHERE c.reporter.id = :reporterId "
                    + "AND (c.category IS NULL OR c.category <> :excluded) ORDER BY c.createdAt DESC",
            countQuery = "SELECT COUNT(c) FROM Complaint c WHERE c.reporter.id = :reporterId "
                    + "AND (c.category IS NULL OR c.category <> :excluded)")
    Page<Complaint> findOwnReports(@org.springframework.data.repository.query.Param("reporterId") Long reporterId,
                                   @org.springframework.data.repository.query.Param("excluded") String excluded,
                                   Pageable pageable);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "reporter.providerProfile", "targetUser", "targetUser.providerProfile", "targetProvider", "targetProvider.user", "targetProvider.user.providerProfile", "booking"})
    Page<Complaint> findByStatusOrderByCreatedAtDesc(ComplaintStatus status, Pageable pageable);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "reporter.providerProfile", "targetUser", "targetUser.providerProfile", "targetProvider", "targetProvider.user", "targetProvider.user.providerProfile", "booking"})
    Page<Complaint> findByFlaggedTrueOrderByCreatedAtDesc(Pageable pageable);
    long countByStatus(ComplaintStatus status);

    // R4 follow-up: server-side search of the admin queues. The pattern comes from com.aiwa.util.Searches ("%" = no search).
    String SEARCH_WHERE = "(LOWER(c.description) LIKE :q OR LOWER(c.category) LIKE :q OR LOWER(r.fullName) LIKE :q "
            + "OR LOWER(tu.fullName) LIKE :q OR LOWER(tp.businessName) LIKE :q)";
    String SEARCH_FROM = "FROM Complaint c LEFT JOIN c.reporter r LEFT JOIN c.targetUser tu LEFT JOIN c.targetProvider tp ";

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "reporter.providerProfile", "targetUser", "targetUser.providerProfile", "targetProvider", "targetProvider.user", "targetProvider.user.providerProfile", "booking"})
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT c " + SEARCH_FROM + "WHERE " + SEARCH_WHERE + " ORDER BY c.createdAt DESC",
            countQuery = "SELECT COUNT(c) " + SEARCH_FROM + "WHERE " + SEARCH_WHERE)
    Page<Complaint> searchAll(@org.springframework.data.repository.query.Param("q") String q, Pageable pageable);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "reporter.providerProfile", "targetUser", "targetUser.providerProfile", "targetProvider", "targetProvider.user", "targetProvider.user.providerProfile", "booking"})
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT c " + SEARCH_FROM + "WHERE c.status = :status AND " + SEARCH_WHERE + " ORDER BY c.createdAt DESC",
            countQuery = "SELECT COUNT(c) " + SEARCH_FROM + "WHERE c.status = :status AND " + SEARCH_WHERE)
    Page<Complaint> searchByStatus(@org.springframework.data.repository.query.Param("status") ComplaintStatus status,
                                   @org.springframework.data.repository.query.Param("q") String q, Pageable pageable);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "reporter.providerProfile", "targetUser", "targetUser.providerProfile", "targetProvider", "targetProvider.user", "targetProvider.user.providerProfile", "booking"})
    @org.springframework.data.jpa.repository.Query(
            value = "SELECT c " + SEARCH_FROM + "WHERE c.flagged = true AND " + SEARCH_WHERE + " ORDER BY c.createdAt DESC",
            countQuery = "SELECT COUNT(c) " + SEARCH_FROM + "WHERE c.flagged = true AND " + SEARCH_WHERE)
    Page<Complaint> searchFlagged(@org.springframework.data.repository.query.Param("q") String q, Pageable pageable);

    /** Same rule as ComplaintServiceImpl.priorityOf → HIGH. */
    @org.springframework.data.jpa.repository.Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = :status "
            + "AND (c.flagged = true OR UPPER(c.category) IN ('SAFETY', 'PAYMENT'))")
    long countHighPriorityByStatus(@org.springframework.data.repository.query.Param("status") ComplaintStatus status);
}
