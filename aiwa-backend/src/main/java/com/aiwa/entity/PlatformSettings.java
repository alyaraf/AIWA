package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

/**
 * Single-row table holding platform-wide, admin-editable settings.
 * Currently the commission rate; future platform knobs belong here too.
 */
@Entity
@Table(name = "platform_settings")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class PlatformSettings extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Platform commission as a percentage of the service price (0–100). */
    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal commissionPercent;

    /** Free-cancellation cutoff before the appointment (hours). Null = use config default. */
    private Integer cancellationCutoffHours;

    /** Provider late-cancel penalty as a percentage of service price. Null = use config default. */
    @Column(precision = 5, scale = 2)
    private BigDecimal providerCancelPenaltyPercent;

    /** Minutes a PENDING request waits before auto-expiring. Null = use config default. */
    private Long responseWindowMinutes;
}
