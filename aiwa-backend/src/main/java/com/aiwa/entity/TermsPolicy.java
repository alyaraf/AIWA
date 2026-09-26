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

    @Column(nullable = false, unique = true)
    private String version;       // e.g. "1.0", "1.1"

    private String type;          // CUSTOMER_TERMS, PROVIDER_TERMS, PRIVACY, SAFETY

    @Column(length = 50000)
    private String contentEn;

    @Column(length = 50000)
    private String contentAr;

    @Builder.Default
    private boolean active = true;
}
