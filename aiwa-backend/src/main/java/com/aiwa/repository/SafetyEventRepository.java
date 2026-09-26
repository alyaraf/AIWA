package com.aiwa.repository;

import com.aiwa.entity.SafetyEvent;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SafetyEventRepository extends JpaRepository<SafetyEvent, Long> {
    List<SafetyEvent> findByBookingIdOrderByCreatedAtAsc(Long bookingId);
}
