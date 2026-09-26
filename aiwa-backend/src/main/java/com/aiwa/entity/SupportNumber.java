package com.aiwa.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.*;

/**
 * One support contact line. AIWA support can publish several — e.g. a general
 * line, a payments line, a city-specific line — with exactly one marked primary.
 */
@Embeddable
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SupportNumber {

    /** Short human label, e.g. "General", "Payments", "Cairo line". */
    @Column(name = "label")
    private String label;

    /** E.164-ish number used for the wa.me / tel link. */
    @Column(name = "number", nullable = false)
    private String number;

    /** Pretty form shown in the apps, e.g. "+20 100 555 0000". */
    @Column(name = "display_number")
    private String displayNumber;

    /** The line the apps surface first. Exactly one enabled number is primary. */
    @Column(name = "is_primary")
    private boolean primary;

    @Column(name = "enabled")
    @Builder.Default
    private boolean enabled = true;
}
