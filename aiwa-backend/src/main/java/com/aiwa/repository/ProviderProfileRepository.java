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

    /** Row lock on the provider — serialises slot conflict-check + insert per provider. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM ProviderProfile p WHERE p.id = :id")
    Optional<ProviderProfile> lockById(@Param("id") Long id);

    // ── Geo search (only APPROVED providers) ─────────────────────────────────
    @Query("""
        SELECT p FROM ProviderProfile p
        WHERE p.latitude IS NOT NULL AND p.longitude IS NOT NULL
          AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED
          AND (6371 * acos(
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )) <= :radiusKm
        ORDER BY (6371 * acos(
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )) ASC
        """)
    List<ProviderProfile> findNearby(@Param("lat") double lat,
                                      @Param("lng") double lng,
                                      @Param("radiusKm") double radiusKm);

    @Query("""
        SELECT p FROM ProviderProfile p
        WHERE p.primaryCategory = :category
          AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED
          AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL
          AND (6371 * acos(
                cos(radians(:lat)) * cos(radians(p.latitude))
                * cos(radians(p.longitude) - radians(:lng))
                + sin(radians(:lat)) * sin(radians(p.latitude))
              )) <= :radiusKm
        ORDER BY p.averageRating DESC
        """)
    Page<ProviderProfile> findNearbyByCategory(@Param("lat") double lat,
                                                @Param("lng") double lng,
                                                @Param("radiusKm") double radiusKm,
                                                @Param("category") ServiceCategory category,
                                                Pageable pageable);

    @Query("SELECT p FROM ProviderProfile p WHERE LOWER(p.businessName) LIKE LOWER(CONCAT('%', :q, '%')) AND p.verificationStatus = com.aiwa.enums.VerificationStatus.APPROVED")
    Page<ProviderProfile> searchByName(@Param("q") String query, Pageable pageable);

    // ── Verification (req 1, 2) ───────────────────────────────────────────────
    Page<ProviderProfile> findByVerificationStatus(VerificationStatus status, Pageable pageable);
    long countByVerificationStatus(VerificationStatus status);
}
