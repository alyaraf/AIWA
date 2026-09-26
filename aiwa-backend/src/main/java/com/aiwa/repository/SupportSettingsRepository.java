package com.aiwa.repository;

import com.aiwa.entity.SupportSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SupportSettingsRepository extends JpaRepository<SupportSettings, Long> {
    Optional<SupportSettings> findFirstByWhatsappEnabledTrue();
    Optional<SupportSettings> findFirstByOrderByIdAsc();
}
