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
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "targetUser", "targetProvider", "booking"})
    Page<Complaint> findByStatusOrderByCreatedAtDesc(ComplaintStatus status, Pageable pageable);
    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"reporter", "targetUser", "targetProvider", "booking"})
    Page<Complaint> findByFlaggedTrueOrderByCreatedAtDesc(Pageable pageable);
    long countByStatus(ComplaintStatus status);

    /** Same rule as ComplaintServiceImpl.priorityOf → HIGH. */
    @org.springframework.data.jpa.repository.Query("SELECT COUNT(c) FROM Complaint c WHERE c.status = :status "
            + "AND (c.flagged = true OR UPPER(c.category) IN ('SAFETY', 'PAYMENT'))")
    long countHighPriorityByStatus(@org.springframework.data.repository.query.Param("status") ComplaintStatus status);
}
