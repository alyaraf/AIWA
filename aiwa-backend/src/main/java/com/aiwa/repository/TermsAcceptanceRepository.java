package com.aiwa.repository;

import com.aiwa.entity.TermsAcceptance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TermsAcceptanceRepository extends JpaRepository<TermsAcceptance, Long> {
    Optional<TermsAcceptance> findByUserIdAndType(Long userId, String type);
}
