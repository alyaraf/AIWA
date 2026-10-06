package com.aiwa.repository;

import com.aiwa.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByBookingIdOrderByCreatedAtAsc(Long bookingId);

    /** R6 follow-up: the messages of one moderation page, each with its sender, in a single query. */
    @Query("SELECT m FROM ChatMessage m LEFT JOIN FETCH m.sender s LEFT JOIN FETCH s.providerProfile WHERE m.id IN :ids")
    List<ChatMessage> findAllWithSenderByIdIn(@Param("ids") Collection<Long> ids);

    /** AU-10: only the messages after the last one the client has (poll without the full history). */
    List<ChatMessage> findByBookingIdAndIdGreaterThanOrderByIdAsc(Long bookingId, Long afterId);
}
