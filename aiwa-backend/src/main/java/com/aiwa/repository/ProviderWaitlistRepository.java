package com.aiwa.repository;

import com.aiwa.entity.ProviderWaitlistEntry;
import com.aiwa.enums.ServiceCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ProviderWaitlistRepository extends JpaRepository<ProviderWaitlistEntry, Long> {

    /** Open entries for this category, plus "any category" entries. */
    @Query("""
        SELECT w FROM ProviderWaitlistEntry w
        WHERE w.notifiedAt IS NULL
          AND (w.category IS NULL OR w.category = :category)
        """)
    List<ProviderWaitlistEntry> findOpenFor(@Param("category") ServiceCategory category);

    boolean existsByUserIdAndCategoryAndNotifiedAtIsNull(Long userId, ServiceCategory category);

    boolean existsByUserIdAndCategoryIsNullAndNotifiedAtIsNull(Long userId);
}
