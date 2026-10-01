package com.aiwa.entity;

import com.aiwa.enums.SosDeliveryStatus;
import jakarta.persistence.*;
import lombok.*;

/**
 * One SOS text to one recipient, so support can see who was actually reached
 * (BE-37 / R2-03). Before, a failed send was only written to the log.
 */
@Entity
@Table(name = "sos_deliveries")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SosDelivery extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "safety_event_id", nullable = false)
    private SafetyEvent event;

    /** ONCALL (support phones) or CONTACT (the user's trusted contacts). */
    @Column(nullable = false, length = 16)
    private String recipientKind;

    @Column(nullable = false, length = 32)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    @Builder.Default
    private SosDeliveryStatus status = SosDeliveryStatus.PENDING;

    @Builder.Default
    private int attempts = 0;

    @Column(length = 255)
    private String lastError;
}
