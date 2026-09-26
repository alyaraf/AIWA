package com.aiwa.entity;

import com.aiwa.enums.ComplaintStatus;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "complaints")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Complaint extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reporter_id", nullable = false)
    private User reporter;

    /** The user being complained about (nullable — could be a general issue) */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_user_id")
    private User targetUser;

    /** The provider being complained about (nullable) */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_provider_id")
    private ProviderProfile targetProvider;

    /** Related booking (nullable) */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @Column(nullable = false)
    private String category;      // BOOKING, PROVIDER, PAYMENT, SAFETY, OTHER

    @Column(nullable = false, length = 2000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private ComplaintStatus status = ComplaintStatus.OPEN;

    @Column(length = 2000)
    private String adminNotes;

    private Long resolvedByAdminId;

    @Builder.Default
    private boolean flagged = false;
}
