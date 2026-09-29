package com.aiwa.entity;

import com.aiwa.enums.SafetyEventType;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "safety_events")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SafetyEvent extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "actor_id", nullable = false)
    private User actor;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SafetyEventType type;

    private Double latitude;
    private Double longitude;

    @Column(length = 1000)
    private String notes;

    // ── SOS incident handling (only meaningful for type == SOS) ───────────────
    /** Closed either by the person who raised it ("I'm safe") or by support. */
    @Builder.Default
    private boolean resolved = false;

    private java.time.LocalDateTime resolvedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "resolved_by_id")
    private User resolvedBy;

    @Column(length = 1000)
    private String resolutionNotes;
}
