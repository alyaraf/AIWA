package com.aiwa.entity;

import com.aiwa.enums.*;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "moderation_cases")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ModerationCase extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ModerationTargetType targetType;

    @Column(nullable = false)
    private Long targetId;

    @Column(length = 1000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ModerationStatus status = ModerationStatus.OPEN;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id")
    private User admin;

    @Column(length = 1000)
    private String adminNotes;
}
