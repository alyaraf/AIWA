package com.aiwa.entity;

import com.aiwa.enums.LedgerEntryStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "commission_ledger_entries")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CommissionLedgerEntry extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal bookingAmount;

    @Column(nullable = false, precision = 5, scale = 2)
    private BigDecimal commissionPercent;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal commissionAmount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private LedgerEntryStatus status = LedgerEntryStatus.DUE;

    private LocalDateTime settledAt;
}
