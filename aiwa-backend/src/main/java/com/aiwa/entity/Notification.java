package com.aiwa.entity;

import com.aiwa.enums.NotificationType;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "notifications")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Notification extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private NotificationType type;

    @Column(nullable = false)
    private String titleEn;

    @Column(nullable = false)
    private String titleAr;

    @Column(length = 1000)
    private String bodyEn;

    @Column(length = 1000)
    private String bodyAr;

    /** Related booking id, if applicable */
    private Long relatedBookingId;

    /** Related provider id, if applicable */
    private Long relatedProviderId;

    @Builder.Default
    private boolean read = false;
}
