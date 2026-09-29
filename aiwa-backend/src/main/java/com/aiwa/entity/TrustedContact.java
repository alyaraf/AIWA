package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

/** Someone the user wants alerted (by SMS) when they trigger an SOS during a booking. */
@Entity
@Table(name = "trusted_contacts")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class TrustedContact extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, length = 32)
    private String phone;

    @Column(length = 60)
    private String relationship;
}
