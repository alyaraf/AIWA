package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "saved_addresses")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class SavedAddress extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String label;

    @Column(nullable = false)
    private String addressLine;

    private Double latitude;
    private Double longitude;

    @Builder.Default
    private boolean defaultAddress = false;

    /** Hidden from the list but kept because past bookings still point at it. */
    @Builder.Default
    private boolean archived = false;
}
