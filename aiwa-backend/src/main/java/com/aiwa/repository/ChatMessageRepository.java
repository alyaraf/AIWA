package com.aiwa.repository;

import com.aiwa.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByBookingIdOrderByCreatedAtAsc(Long bookingId);

    /** AU-10: only the messages after the last one the client has (poll without the full history). */
    List<ChatMessage> findByBookingIdAndIdGreaterThanOrderByIdAsc(Long bookingId, Long afterId);
}
