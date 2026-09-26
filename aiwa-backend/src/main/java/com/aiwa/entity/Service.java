package com.aiwa.entity;

import com.aiwa.enums.PricingType;
import com.aiwa.enums.ServiceCategory;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "services")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Service extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    @Column(nullable = false)
    private String name;

    private String description;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    /** Duration in minutes */
    @Column(nullable = false)
    private Integer durationMinutes;

    @Enumerated(EnumType.STRING)
    private ServiceCategory category;

    /** Gap 2: FIXED price or STARTS_AT (flow req — pricing display rules) */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private PricingType pricingType = PricingType.FIXED;

    /** Gap 2: whether transportation/Uber cost is included in the price */
    @Builder.Default
    private boolean transportIncluded = false;

    @Builder.Default
    private boolean active = true;

    @OneToMany(mappedBy = "service", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Booking> bookings = new ArrayList<>();
}
