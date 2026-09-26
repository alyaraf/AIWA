package com.aiwa.repository;

import com.aiwa.entity.OtpCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface OtpRepository extends JpaRepository<OtpCode, Long> {
    Optional<OtpCode> findTopByPhoneAndUsedFalseOrderByCreatedAtDesc(String phone);
    void deleteAllByPhone(String phone);
}
