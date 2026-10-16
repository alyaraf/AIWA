package com.aiwa.repository;

import com.aiwa.entity.AuditLogEntry;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLogEntry, Long> {

    Page<AuditLogEntry> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @Query("""
        SELECT a FROM AuditLogEntry a
        WHERE lower(a.actor)  LIKE lower(concat('%', :q, '%'))
           OR lower(a.action) LIKE lower(concat('%', :q, '%'))
           OR lower(coalesce(a.target, '')) LIKE lower(concat('%', :q, '%'))
        ORDER BY a.createdAt DESC
        """)
    Page<AuditLogEntry> search(@Param("q") String q, Pageable pageable);

    /**
     * AQ-02: rows written before actors were logged by id name a customer or provider by the email or phone they
     * signed in with. Account deletion replaces those ({@code identifiers} lower-case) with the account's id.
     */
    @org.springframework.data.jpa.repository.Modifying
    @Query("UPDATE AuditLogEntry a SET a.actor = :label WHERE lower(a.actor) IN :identifiers")
    int replaceActor(@Param("identifiers") java.util.Collection<String> identifiers, @Param("label") String label);
}
