package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "terms_policies")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TermsPolicy extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Unique per type (V13) — customer and provider terms can both be "1.0". */
    @Column(nullable = false)
    private String version;       // e.g. "1.0", "1.1"

    private String type;          // CUSTOMER_TERMS, PROVIDER_TERMS, PRIVACY, SAFETY

    @Column(length = 50000)
    private String contentEn;

    @Column(length = 50000)
    private String contentAr;

    /** Optional link to a printable/PDF copy of this version. */
    @Column(length = 512)
    private String pdfUrl;

    @Builder.Default
    private boolean active = true;
}
