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
    boolean existsByBookingId(Long bookingId);

    @Query("SELECT COALESCE(SUM(e.commissionAmount), 0) FROM CommissionLedgerEntry e WHERE e.provider.id = :providerId AND e.status = :status")
    BigDecimal sumByProviderAndStatus(@Param("providerId") Long providerId, @Param("status") LedgerEntryStatus status);

    @Query("SELECT COUNT(DISTINCT e.provider.id) FROM CommissionLedgerEntry e WHERE e.status = :status")
    long countDistinctProvidersByStatus(@Param("status") LedgerEntryStatus status);
}
