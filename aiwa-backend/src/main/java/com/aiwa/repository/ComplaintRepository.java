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
    Page<Complaint> findByStatusOrderByCreatedAtDesc(ComplaintStatus status, Pageable pageable);
    Page<Complaint> findByFlaggedTrueOrderByCreatedAtDesc(Pageable pageable);
    long countByStatus(ComplaintStatus status);
}
