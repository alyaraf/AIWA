package com.aiwa.entity;

import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.enums.ProviderType;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "provider_profiles")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ProviderProfile extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Optimistic lock: two status changes racing on the same row can't both win (BE-38). */
    @Version
    @Column(nullable = false)
    private long version;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(nullable = false)
    private String businessName;

    private String bio;
    private String address;
    private Double latitude;
    private Double longitude;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private ProviderType providerType = ProviderType.INDIVIDUAL;

    @Enumerated(EnumType.STRING)
    private ServiceCategory primaryCategory;

    private Double averageRating;

    @Builder.Default
    private Integer totalReviews = 0;

    @Builder.Default
    private boolean vacationMode = false;

    @Builder.Default
    private boolean offlineMode = false;

    @Builder.Default
    private Integer travelBufferMinutes = 0;

    @Builder.Default
    private Integer cancellationStrikes = 0;

    @Builder.Default
    private boolean settlementPaused = false;

    /**
     * SA-08: set by the three-strike cancellation pause (AU-07). Separate from settlementPaused,
     * which settling commission clears; only an admin lifting the pause clears this one.
     */
    @Builder.Default
    @Column(name = "disciplinary_hold", nullable = false)
    private boolean disciplinaryHold = false;

    /** Paused for any reason: unpaid commission or a disciplinary review. */
    public boolean isBookingPaused() {
        return settlementPaused || disciplinaryHold;
    }

    // ── Per-provider overrides (null = fall back to the platform setting) ──────
    /** Custom platform commission for this provider (%). Null = use the platform rate. */
    @Column(precision = 5, scale = 2)
    private BigDecimal commissionOverridePercent;

    /** Custom free-cancellation cutoff (hours). Null = use the platform rule. */
    private Integer cancellationCutoffHoursOverride;

    /** Custom provider late-cancel penalty (%). Null = use the platform rule. */
    @Column(precision = 5, scale = 2)
    private BigDecimal providerCancelPenaltyPercentOverride;

    /** Custom pending-request response window (minutes). Null = use the platform rule. */
    private Long responseWindowMinutesOverride;

    /**
     * Flat EGP fee added to any home-service booking to cover the provider's travel
     * cost (Uber, fuel, taxi). Null / 0 = the provider does not charge travel;
     * they cover it themselves or don't offer home service. Snapshotted onto
     * Booking.travelFee at creation time so later profile edits don't retroactively
     * change historical receipts.
     */
    @Column(precision = 10, scale = 2)
    private BigDecimal homeServiceTravelFee;

    // ── Verification (req 1, 2) ────────────────────────────────────────────────
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private VerificationStatus verificationStatus = VerificationStatus.PENDING_VERIFICATION;

    /** Path/URL to national ID front image (private storage) */
    private String nationalIdFrontPath;

    /** Path/URL to national ID back image (private storage) */
    private String nationalIdBackPath;

    /** Path/URL to live selfie image (private storage) */
    private String selfiePath;

    /** Admin rejection reason if verificationStatus = REJECTED */
    private String rejectionReason;

    /** Admin-only note on the verification case; never shown to the provider. */
    @Column(length = 2000)
    private String verificationNote;

    /** When an admin last approved this provider (the "Verified since" badge). */
    private java.time.LocalDateTime verifiedAt;

    /** How far the provider travels for home-service bookings (km). Null = no stated limit. */
    private Double serviceRadiusKm;

    /**
     * Set when the provider reports that they paid their outstanding commission
     * (cash hand-over / transfer). Finance still has to confirm the payout before
     * any ledger entry is marked SETTLED; cleared on confirmation.
     */
    private java.time.LocalDateTime settlementReportedAt;

    /** Legacy boolean — derived from verificationStatus */
    public boolean isVerified() {
        return VerificationStatus.APPROVED.equals(this.verificationStatus);
    }

    // ── Gallery (req 3) ────────────────────────────────────────────────────────
    @OneToMany(mappedBy = "provider", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("id ASC")
    @Builder.Default
    private List<GalleryImage> gallery = new ArrayList<>();

    /** Public gallery: URLs of the images that moderation has not hidden. */
    public List<String> getVisibleGalleryUrls() {
        return gallery.stream().filter(g -> !g.isHidden()).map(GalleryImage::getUrl).toList();
    }

    // ── Relations ─────────────────────────────────────────────────────────────
    @OneToMany(mappedBy = "provider", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Service> services = new ArrayList<>();

    @OneToMany(mappedBy = "provider", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Availability> availabilities = new ArrayList<>();

    @OneToMany(mappedBy = "provider", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<StaffMember> staffMembers = new ArrayList<>();

    @OneToMany(mappedBy = "provider", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Booking> bookings = new ArrayList<>();

    @OneToMany(mappedBy = "provider", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Review> reviews = new ArrayList<>();
}
