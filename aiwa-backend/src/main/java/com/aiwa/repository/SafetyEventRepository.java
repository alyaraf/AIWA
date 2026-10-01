package com.aiwa.repository;

import com.aiwa.entity.SafetyEvent;
import com.aiwa.enums.SafetyEventType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface SafetyEventRepository extends JpaRepository<SafetyEvent, Long> {
    List<SafetyEvent> findByBookingIdOrderByCreatedAtAsc(Long bookingId);

    Optional<SafetyEvent> findByIdAndBookingId(Long id, Long bookingId);

    /** Admin SOS queue. */
    Page<SafetyEvent> findByTypeAndResolvedOrderByCreatedAtDesc(SafetyEventType type, boolean resolved, Pageable pageable);

    Page<SafetyEvent> findByTypeOrderByCreatedAtDesc(SafetyEventType type, Pageable pageable);

    long countByTypeAndResolvedFalse(SafetyEventType type);

    Optional<SafetyEvent> findFirstByTypeAndResolvedFalseOrderByCreatedAtAsc(SafetyEventType type);

    Optional<SafetyEvent> findFirstByBookingIdAndActorIdAndTypeAndResolvedFalseOrderByCreatedAtDesc(
            Long bookingId, Long actorId, SafetyEventType type);

    long countByActorIdAndTypeAndCreatedAtAfter(Long actorId, SafetyEventType type, java.time.LocalDateTime after);
}
