package com.aiwa.entity;

import com.aiwa.enums.Gender;
import com.aiwa.enums.Language;
import com.aiwa.enums.UserRole;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "users")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class User extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String fullName;

    @Column(unique = true)
    private String email;

    @Column(unique = true)
    private String phone;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserRole role;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    private String profileImageUrl;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private Language preferredLanguage = Language.EN;

    private String acceptedTermsVersion;
    private LocalDateTime termsAcceptedAt;

    @Builder.Default
    private boolean termsAccepted = false;

    private Double searchRadiusMinKm;
    private Double searchRadiusMaxKm;

    /** Where discovery starts when the customer doesn't want to use GPS ("Your area"). */
    private String searchAreaLabel;
    private Double searchAreaLatitude;
    private Double searchAreaLongitude;

    /**
     * Session cut-off: access/refresh tokens issued before this instant are
     * rejected. Set on password reset, phone change and admin deactivation so
     * stolen or stale sessions die immediately instead of at token expiry.
     */
    private java.time.Instant tokensValidAfter;

    // ── Notification preferences (channels + quiet hours) ─────────────────────
    @Builder.Default
    private boolean notifyPush = true;
    @Builder.Default
    private boolean notifyEmail = true;
    @Builder.Default
    private boolean notifySms = true;
    @Builder.Default
    private boolean notifyWhatsapp = false;
    @Builder.Default
    private boolean muteAll = false;
    private java.time.LocalTime quietHoursStart;
    private java.time.LocalTime quietHoursEnd;

    // ── Push delivery (device registration) ────────────────────────────────────
    /** FCM/APNs registration id for this device. Null until the app registers one. */
    @Column(length = 512)
    private String pushToken;

    @Enumerated(EnumType.STRING)
    private com.aiwa.enums.DevicePlatform pushPlatform;

    // ── Two-factor authentication (TOTP) ────────────────────────────────────────
    /** Base32 secret. Set as soon as setup starts; only trusted for login once
     *  totpEnabled is true (setup isn't "on" until the first code is confirmed). */
    private String totpSecret;

    @Builder.Default
    private boolean totpEnabled = false;

    // ── Admin permissions (only meaningful when role == ADMIN) ────────────────
    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "admin_permissions", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "permission")
    @Enumerated(EnumType.STRING)
    @Builder.Default
    private java.util.Set<com.aiwa.enums.AdminPermission> adminPermissions = new java.util.HashSet<>();

    public boolean hasPermission(com.aiwa.enums.AdminPermission permission) {
        return adminPermissions != null && adminPermissions.contains(permission);
    }

    @OneToOne(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private ProviderProfile providerProfile;

    @OneToMany(mappedBy = "customer", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Booking> bookings = new ArrayList<>();

    @OneToMany(mappedBy = "user", fetch = FetchType.LAZY)
    @Builder.Default
    private List<Review> reviews = new ArrayList<>();

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<Notification> notifications = new ArrayList<>();

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @Builder.Default
    private List<SavedAddress> savedAddresses = new ArrayList<>();
}
