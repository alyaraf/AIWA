package com.aiwa.repository;

import com.aiwa.entity.TermsPolicy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TermsPolicyRepository extends JpaRepository<TermsPolicy, Long> {
    /** Newest live version — ordered by publish time, not by the version string ("1.10" < "1.9"). */
    Optional<TermsPolicy> findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc(String type);
    Optional<TermsPolicy> findByTypeAndVersion(String type, String version);
    boolean existsByTypeAndVersion(String type, String version);
    List<TermsPolicy> findByTypeOrderByCreatedAtDescIdDesc(String type);
    List<TermsPolicy> findByTypeAndActiveTrue(String type);
}
