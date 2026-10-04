package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/** AU-19: the version of one document type a user accepted (V29). */
@Entity
@Table(name = "terms_acceptances",
        uniqueConstraints = @UniqueConstraint(name = "ux_terms_acceptances_user_type", columnNames = {"user_id", "type"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TermsAcceptance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    /** CUSTOMER_TERMS, PROVIDER_TERMS, PRIVACY or SAFETY. */
    @Column(nullable = false, length = 32)
    private String type;

    @Column(nullable = false)
    private String version;

    @Column(name = "accepted_at", nullable = false)
    private LocalDateTime acceptedAt;
}
