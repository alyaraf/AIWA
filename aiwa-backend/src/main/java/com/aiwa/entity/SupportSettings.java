package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "support_settings")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SupportSettings extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * Primary WhatsApp number — kept as a flat column for backward compatibility
     * with the public {@code /support/contact} response the mobile apps read.
     * Mirrored from the primary entry in {@link #numbers} on every save.
     */
    @Column(nullable = false)
    private String whatsappNumber;

    private String whatsappNumberDisplay;

    private String supportEmail;

    /** e.g. "Sun–Thu 9AM–6PM EET" */
    private String availabilityHoursEn;
    private String availabilityHoursAr;

    @Builder.Default
    private boolean whatsappEnabled = true;

    /** All published support lines, ordered. Exactly one enabled entry is primary. */
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "support_numbers", joinColumns = @JoinColumn(name = "support_settings_id"))
    @OrderColumn(name = "sort_order")
    @Builder.Default
    private List<SupportNumber> numbers = new ArrayList<>();
}
