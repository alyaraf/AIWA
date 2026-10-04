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

    /**
     * Optimistic lock (DR-031): a profile, avatar or preference save that loaded
     * the user before an admin suspended them used to write active=true and the
     * old session cut-off back. Now that save fails with 409 instead.
     */
    @Version
    @Column(nullable = false)
    private long version;

    @Column(nullable = false)
    private String fullName;

    @Column(unique = true)
    private String email;

    @Column(unique = true)
    private String phone;

    /**
     * An email the owner has not confirmed with a code yet (CR-05). Only
     * {@link #email} signs in, resets a password or is unique; this one moves
     * there on POST /auth/me/email/verify.
     */
    private String pendingEmail;

    // CR-02: the one place an email or phone is written (these setters and the
    // builder below), so no caller can store a spelling sign-in does not look
    // up. Hibernate loads by field, so a row V19 left as stored is not rewritten
    // on load. A non-email throws IllegalArgumentException: callers check first.
    public void setEmail(String email) {
        this.email = com.aiwa.util.Identifiers.normalizeEmail(email);
    }

    public void setPhone(String phone) {
        this.phone = com.aiwa.util.Identifiers.normalizePhone(phone);
    }

    /** Lombok fills in the rest of the builder. */
    public static class UserBuilder {
        public UserBuilder email(String email) {
            this.email = com.aiwa.util.Identifiers.normalizeEmail(email);
            return this;
        }

        public UserBuilder phone(String phone) {
            this.phone = com.aiwa.util.Identifiers.normalizePhone(phone);
            return this;
        }
    }

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
    @jakarta.persistence.Convert(converter = com.aiwa.util.TotpSecretConverter.class) // AU-08: encrypted at rest
    private String totpSecret;

    @Builder.Default
    private boolean totpEnabled = false;

    /** Time step of the last accepted code: that step and older ones are refused, so a code works once (CR-01). */
    private Long totpLastUsedStep;

    // ── Sign-in attempt limit (CR-01) ───────────────────────────────────────────
    // Written only by the single-statement updates in UserRepository
    // (updatable = false): a profile save that loaded the user earlier can
    // never put an old count back and lift a lock.
    /** Sign-in attempts (password or 2FA code) since the last successful sign-in. */
    @Column(nullable = false, updatable = false)
    @Builder.Default
    private int failedLoginAttempts = 0;

    /** When the last of those attempts was made; the lock period runs from here. */
    @Column(updatable = false)
    private java.time.Instant lastFailedLoginAt;

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
