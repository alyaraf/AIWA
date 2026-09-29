package com.aiwa.entity;

import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.BookingType;
import com.aiwa.enums.PaymentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Entity
@Table(name = "bookings")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Booking extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "provider_id", nullable = false)
    private ProviderProfile provider;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_id", nullable = false)
    private Service service;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "staff_member_id")
    private StaffMember staffMember;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "saved_address_id")
    private SavedAddress savedAddress;

    @Column(nullable = false)
    private LocalDate bookingDate;

    @Column(nullable = false)
    private LocalTime startTime;

    @Column(nullable = false)
    private LocalTime endTime;

    /** Gap 1: SCHEDULED vs BOOK_NOW */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private BookingType bookingType = BookingType.SCHEDULED;

    /** Gap 3: estimated arrival time in minutes (for BOOK_NOW) */
    private Integer estimatedArrivalMinutes;

    @Builder.Default
    private boolean homeService = false;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private BookingStatus status = BookingStatus.PENDING;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal totalPrice;

    /**
     * Snapshot of the provider's home-service travel fee at the time of booking.
     * Null for non-home-service bookings, or when the provider has no travel fee set.
     * totalPrice = service.price + (travelFee ?? 0). Kept separate so commission is
     * charged on the service portion only (travel is pass-through to the provider).
     */
    @Column(precision = 10, scale = 2)
    private BigDecimal travelFee;

    private String notes;

    // ── Cancellation tracking ─────────────────────────────────────────────────
    private String cancellationReason;
    private String cancelledBy;
    private LocalDateTime cancelledAt;

    // ── Rejection tracking ────────────────────────────────────────────────────
    private String rejectionReason;

    // ── Provider-proposed alternative slot (awaiting customer accept/decline) ──
    private LocalDate proposedDate;
    private LocalTime proposedStartTime;
    /** When the alternative slot was proposed; it lapses after the response window. */
    private LocalDateTime proposedAt;

    // ── Per-booking travel-fee quote (home service) ───────────────────────────
    /** Amount the provider quoted for travel on this booking; replaces the flat fee once accepted. */
    @Column(precision = 10, scale = 2)
    private BigDecimal travelFeeQuote;

    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private com.aiwa.enums.TravelFeeQuoteStatus travelFeeQuoteStatus;

    /** Provider's explanation when completing without collecting cash (feeds the dispute). */
    @Column(length = 500)
    private String completionNote;

    /** True when a penalty applies (provider cancel after accept, or no-show). */
    @Builder.Default
    private boolean penaltyApplied = false;

    /** Platform commission recorded for this booking (denormalized for display). */
    @Column(precision = 10, scale = 2)
    private BigDecimal commissionAmount;

    /** Set when the customer checks in at an on-site/venue booking. */
    private LocalDateTime checkedInAt;

    // ── Payment ───────────────────────────────────────────────────────────────
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private PaymentStatus paymentStatus = PaymentStatus.UNPAID;

    /** Gap 1: selected at booking time — "CASH" for v1, future: CARD, ONLINE */
    @Builder.Default
    private String paymentMethod = "CASH";

    @OneToMany(mappedBy = "booking", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private java.util.List<Review> reviews = new java.util.ArrayList<>();
}
