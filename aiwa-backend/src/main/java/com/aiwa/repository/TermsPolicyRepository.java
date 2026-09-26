package com.aiwa.repository;

import com.aiwa.entity.TermsPolicy;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TermsPolicyRepository extends JpaRepository<TermsPolicy, Long> {
    Optional<TermsPolicy> findFirstByTypeAndActiveTrueOrderByVersionDesc(String type);
    Optional<TermsPolicy> findByVersion(String version);
}
