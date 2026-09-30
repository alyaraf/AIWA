package com.aiwa.repository;

import com.aiwa.entity.SavedAddress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface SavedAddressRepository extends JpaRepository<SavedAddress, Long> {
    List<SavedAddress> findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc(Long userId);

    /** Including archived ones: account deletion scrubs them all. */
    List<SavedAddress> findByUserId(Long userId);

    /** Only one default per user: clear it everywhere else before setting it. */
    @Modifying
    @Query("UPDATE SavedAddress a SET a.defaultAddress = false WHERE a.user.id = :userId AND a.id <> :keepId")
    void clearDefaultExcept(@Param("userId") Long userId, @Param("keepId") Long keepId);
}
