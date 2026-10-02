package com.aiwa.repository;

import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.enums.LedgerEntryStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;

public interface CommissionLedgerRepository extends JpaRepository<CommissionLedgerEntry, Long> {
    List<CommissionLedgerEntry> findByProviderIdOrderByCreatedAtDesc(Long providerId);
    List<CommissionLedgerEntry> findByStatusOrderByCreatedAtAsc(LedgerEntryStatus status);
    List<CommissionLedgerEntry> findByStatusIn(java.util.Collection<LedgerEntryStatus> statuses);
    List<CommissionLedgerEntry> findByProviderIdAndStatusIn(Long providerId, java.util.Collection<LedgerEntryStatus> statuses);
    List<CommissionLedgerEntry> findAllByOrderByCreatedAtDesc();

    // ── DR-028: paged / aggregated in the database instead of loading every row ──

    org.springframework.data.domain.Page<CommissionLedgerEntry> findByStatusOrderByCreatedAtAsc(
            LedgerEntryStatus status, org.springframework.data.domain.Pageable pageable);

    org.springframework.data.domain.Slice<CommissionLedgerEntry> findAllByOrderByIdDesc(
            org.springframework.data.domain.Pageable pageable);

    /**
     * One row per provider with ledger entries:
     * [providerId, outstanding gross, outstanding commission, overdue count,
     *  outstanding count, oldest outstanding createdAt].
     */
    @Query(value = """
        SELECT e.provider.id,
               SUM(CASE WHEN e.status IN (com.aiwa.enums.LedgerEntryStatus.DUE, com.aiwa.enums.LedgerEntryStatus.OVERDUE)
                        THEN e.bookingAmount ELSE 0 END),
               SUM(CASE WHEN e.status IN (com.aiwa.enums.LedgerEntryStatus.DUE, com.aiwa.enums.LedgerEntryStatus.OVERDUE)
                        THEN e.commissionAmount ELSE 0 END),
               SUM(CASE WHEN e.status = com.aiwa.enums.LedgerEntryStatus.OVERDUE THEN 1 ELSE 0 END),
               SUM(CASE WHEN e.status IN (com.aiwa.enums.LedgerEntryStatus.DUE, com.aiwa.enums.LedgerEntryStatus.OVERDUE)
                        THEN 1 ELSE 0 END),
               MIN(CASE WHEN e.status IN (com.aiwa.enums.LedgerEntryStatus.DUE, com.aiwa.enums.LedgerEntryStatus.OVERDUE)
                        THEN e.createdAt END)
        FROM CommissionLedgerEntry e
        GROUP BY e.provider.id
        ORDER BY MAX(e.createdAt) DESC
        """,
        countQuery = "SELECT COUNT(DISTINCT e.provider.id) FROM CommissionLedgerEntry e")
    org.springframework.data.domain.Page<Object[]> providerTotals(org.springframework.data.domain.Pageable pageable);

    @Query("SELECT COALESCE(SUM(e.commissionAmount), 0) FROM CommissionLedgerEntry e WHERE e.status IN :statuses")
    BigDecimal sumByStatusIn(@Param("statuses") java.util.Collection<LedgerEntryStatus> statuses);

    @Query("SELECT COUNT(DISTINCT e.provider.id) FROM CommissionLedgerEntry e WHERE e.status IN :statuses")
    long countDistinctProvidersByStatusIn(@Param("statuses") java.util.Collection<LedgerEntryStatus> statuses);
    boolean existsByBookingId(Long bookingId);
    java.util.Optional<CommissionLedgerEntry> findByBookingId(Long bookingId);

    @Query("SELECT COUNT(DISTINCT e.provider.id) FROM CommissionLedgerEntry e WHERE e.status = :status")
    long countDistinctProvidersByStatus(@Param("status") LedgerEntryStatus status);
}
