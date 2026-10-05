package com.aiwa.repository;

import com.aiwa.entity.SavedProvider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface SavedProviderRepository extends JpaRepository<SavedProvider, Long> {
    List<SavedProvider> findByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<SavedProvider> findByUserIdAndProviderId(Long userId, Long providerId);
    boolean existsByUserIdAndProviderId(Long userId, Long providerId);
    @org.springframework.transaction.annotation.Transactional
    void deleteByUserIdAndProviderId(Long userId, Long providerId);
}
