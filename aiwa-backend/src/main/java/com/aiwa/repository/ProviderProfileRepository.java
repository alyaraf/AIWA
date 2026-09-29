package com.aiwa.repository;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.VerificationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ProviderProfileRepository extends JpaRepository<ProviderProfile, Long> {

    Optional<ProviderProfile> findByUserId(Long userId);

    // ── Geo search (only APPROVED providers) ─────────────────────────────────
    // The acos argument is clamped to [-1, 1]: floating-point rounding can push it
    // a hair past 1 for a provider at (almost) the search point, and PostgreSQL
    // then fails the whole query with "input is out of range".
    @Query("""
        SELECT p FROM ProviderProfile p
        WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL
          AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED
          AND (6371 * acos(least(1.0, greatest(-1.0,
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )))) <= :radiusKm
        ORDER BY (6371 * acos(least(1.0, greatest(-1.0,
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )))) ASC
        """)
    List<ProviderProfile> findNearby(@Param("lat") double lat,
                                      @Param("lng") double lng,
                                      @Param("radiusKm") double radiusKm);

    /** Nearby providers whose primary category, or any active service, is in {@code category}. */
    @Query("""
        SELECT p FROM ProviderProfile p
        WHERE (p.primaryCategory = :category
               OR EXISTS (SELECT 1 FROM Service s
                          WHERE s.provider = p AND s.active = true AND s.category = :category))
          AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED
          AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL
          AND (6371 * acos(least(1.0, greatest(-1.0,
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )))) <= :radiusKm
        """)
    List<ProviderProfile> findNearbyByCategory(@Param("lat") double lat,
                                                @Param("lng") double lng,
                                                @Param("radiusKm") double radiusKm,
                                                @Param("category") ServiceCategory category);

    @Query("SELECT p FROM ProviderProfile p WHERE LOWER(p.businessName) LIKE LOWER(CONCAT('%', :q, '%')) AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED")
    Page<ProviderProfile> searchByName(@Param("q") String query, Pageable pageable);

    // ── Verification (req 1, 2) ───────────────────────────────────────────────
    Page<ProviderProfile> findByVerificationStatus(VerificationStatus status, Pageable pageable);

    /** Providers who reported paying commission that finance hasn't confirmed yet. */
    List<ProviderProfile> findBySettlementReportedAtIsNotNullOrderBySettlementReportedAtAsc(Pageable pageable);
    long countByVerificationStatus(VerificationStatus status);

    long countByVerificationStatusAndVerifiedAtAfter(VerificationStatus status, java.time.LocalDateTime after);

    /** True when this exact storage path was submitted by some provider as an ID / selfie document. */
    boolean existsByNationalIdFrontPathOrNationalIdBackPathOrSelfiePath(String front, String back, String selfie);

    /**
     * Row-locks the provider for the rest of the transaction. Booking creation,
     * rescheduling and proposal acceptance take this lock before their slot
     * conflict check, so two simultaneous requests for the same calendar are
     * serialized instead of both passing the check and double-booking.
     */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.QueryHints(
            @jakarta.persistence.QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("SELECT p FROM ProviderProfile p WHERE p.id = :id")
    Optional<ProviderProfile> findByIdForUpdate(@Param("id") Long id);
}
