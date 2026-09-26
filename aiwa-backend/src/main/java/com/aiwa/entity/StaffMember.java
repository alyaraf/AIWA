package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "staff_members")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class StaffMember extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    @Column(nullable = false)
    private String fullName;

    private String title;
    private String phone;

    /** Comma-separated skills / specialties shown on the staff picker. */
    private String skills;

    @Builder.Default
    private boolean active = true;
}
