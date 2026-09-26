package com.aiwa.entity;

import com.aiwa.enums.ChatMessageType;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "chat_messages")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ChatMessage extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ChatMessageType type = ChatMessageType.TEXT;

    @Column(nullable = false, length = 2000)
    private String message;

    @Builder.Default
    private boolean readByRecipient = false;

    /** True once an admin has removed this message after a report; the original
     *  text is kept in the row (for the audit trail) but never served again —
     *  both parties see a fixed "message removed by admin" placeholder instead. */
    @Builder.Default
    private boolean removed = false;
}
