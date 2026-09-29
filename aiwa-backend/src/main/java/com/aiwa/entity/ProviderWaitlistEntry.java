package com.aiwa.entity;

import com.aiwa.enums.ServiceCategory;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * "Notify me when someone joins": a customer who found no provider for a
 * category (optionally near a point). Notified once, when a matching provider
 * is approved.
 */
@Entity
@Table(name = "provider_waitlist")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ProviderWaitlistEntry extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** Null = any category. */
    @Enumerated(EnumType.STRING)
    private ServiceCategory category;

    private Double latitude;
    private Double longitude;

    private LocalDateTime notifiedAt;
}
