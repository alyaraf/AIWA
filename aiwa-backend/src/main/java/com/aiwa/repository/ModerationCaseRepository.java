package com.aiwa.repository;

import com.aiwa.entity.ModerationCase;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ModerationCaseRepository extends JpaRepository<ModerationCase, Long> {
    List<ModerationCase> findByStatusOrderByCreatedAtDesc(ModerationStatus status);
    List<ModerationCase> findByStatusAndTargetTypeOrderByCreatedAtDesc(ModerationStatus status, ModerationTargetType targetType);
}
