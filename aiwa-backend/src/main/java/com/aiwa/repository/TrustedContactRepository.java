package com.aiwa.repository;

import com.aiwa.entity.TrustedContact;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TrustedContactRepository extends JpaRepository<TrustedContact, Long> {
    List<TrustedContact> findByUserIdOrderByCreatedAtAsc(Long userId);
    long countByUserId(Long userId);
}
