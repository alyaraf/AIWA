package com.aiwa.dto.response;

import com.aiwa.enums.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.*;
import java.util.List;

public class ApiResponse {

    // â”€â”€â”€ Generic wrapper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @AllArgsConstructor @NoArgsConstructor @Builder
    public static class Success<T> {
        private boolean success = true;
        private String message;
        private T data;

        public static <T> Success<T> of(T data) {
            return Success.<T>builder().success(true).data(data).build();
        }

        public static <T> Success<T> of(String message, T data) {
            return Success.<T>builder().success(true).message(message).data(data).build();
        }
    }

    @Data @AllArgsConstructor @NoArgsConstructor @Builder
    public static class Error {
        private boolean success = false;
        private int status;
        private String error;
        /** Stable machine-readable reason (the i18n key, e.g. "booking.error.conflict"),
         *  so clients can branch without matching translated message text. */
        private String code;
        private String message;
        private LocalDateTime timestamp = LocalDateTime.now();
    }

    // â”€â”€â”€ Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class OtpSentDto {
        private String phone;
        private String maskedPhone;
        private int expiresInMinutes;
    }

    @Data @Builder
    public static class AuthResponse {
        private String accessToken;
        private String refreshToken;
        private String tokenType;
        private UserDto user;
        /** True when the password check passed but a TOTP code is still needed —
         *  accessToken/refreshToken/user are all null in that case; the client
         *  must call POST /auth/2fa/verify with mfaToken + the 6-digit code. */
        @Builder.Default
        private boolean mfaRequired = false;
        private String mfaToken;
    }

    @Data @Builder
    public static class TwoFactorSetupDto {
        private String secret;
        private String otpAuthUri;
    }

    // â”€â”€â”€ User â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class UserDto {
        private Long id;
        private String fullName;
        private String email;
        private String phone;
        private UserRole role;
        private Gender gender;
        private String profileImageUrl;
        private Language preferredLanguage;
        private boolean termsAccepted;
        /** Version the user last accepted — the app compares it to /terms/latest. */
        private String acceptedTermsVersion;
        private LocalDateTime termsAcceptedAt;
        /**
         * False when a newer policy for the user's role is live than the one they
         * accepted — the app then routes to re-accept. Null where not computed
         * (only GET /auth/me fills it).
         */
        private Boolean termsUpToDate;
        private boolean active;
        private java.util.List<String> permissions;
        private Long providerProfileId;
        private VerificationStatus providerStatus;
        /** Admin's rejection reason or "more info" request while not approved. */
        private String providerNote;
        private Long bookingCount;
        /** Reviews this user has written (customer profile stats tile). */
        private Long reviewCount;
        /** "Your area" — where discovery starts when GPS isn't used. */
        private String searchAreaLabel;
        private Double searchAreaLatitude;
        private Double searchAreaLongitude;
        private LocalDateTime createdAt;
    }

    // â”€â”€â”€ Provider Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ProviderSummaryDto {
        private Long id;
        private String businessName;
        private String address;
        private Double latitude;
        private Double longitude;
        private ServiceCategory primaryCategory;
        private Double averageRating;
        private Integer totalReviews;
        private VerificationStatus verificationStatus;
        private String ownerName;
        private String profileImageUrl;
        private Double distanceKm;
        private Boolean saved;             // true if current user has saved this provider
        private ProviderType providerType;
        private boolean vacationMode;
        private boolean offlineMode;
        private boolean settlementPaused;
        /** Cheapest active service price ("From EGP …"); null when no active service. */
        private BigDecimal startingPrice;
        /** Accepting bookings AND inside today's working hours (Africa/Cairo). */
        private Boolean openNow;
        /** Currently on a visit (ON_THE_WAY / ARRIVED / IN_PROGRESS) — Book Now would wait. */
        private Boolean busyNow;
        private LocalDateTime verifiedAt;
    }

    // â”€â”€â”€ Provider Detail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ProviderDetailDto {
        private Long id;
        private String businessName;
        private String bio;
        private String address;
        private Double latitude;
        private Double longitude;
        private ServiceCategory primaryCategory;
        private Double averageRating;
        private Integer totalReviews;
        private VerificationStatus verificationStatus;
        private ProviderType providerType;
        private boolean vacationMode;
        private boolean offlineMode;
        private Integer travelBufferMinutes;
        private boolean settlementPaused;
        /** Flat EGP fee added to home-service bookings; null/0 = provider does not charge travel. */
        private BigDecimal homeServiceTravelFee;
        private UserDto owner;
        private List<ServiceDto> services;
        private List<AvailabilityDto> availabilities;
        private List<StaffMemberDto> staffMembers;
        private List<String> galleryImages;
        /** Visible photos with their ids, so a customer can report one. */
        private List<GalleryImageDto> gallery;
        private Double distanceKm;
        private BigDecimal startingPrice;
        private Boolean openNow;
        /** An individual provider is mid-booking right now (Book Now "busy"). */
        private Boolean busyNow;
        private LocalDateTime verifiedAt;
        /** How far the provider travels for home service (km); null = not stated. */
        private Double serviceRadiusKm;
    }

    // â”€â”€â”€ Provider Verification (admin view) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ProviderVerificationDto {
        private Long id;
        private String businessName;
        private String ownerName;
        private String ownerEmail;
        private String ownerPhone;
        private ServiceCategory primaryCategory;
        private String city;
        private VerificationStatus verificationStatus;
        private String nationalIdFrontPath;
        private String nationalIdBackPath;
        private String selfiePath;
        private String rejectionReason;
        private LocalDateTime submittedAt;
        // Business profile rows on the admin verification detail (ADMIN-04).
        private Double latitude;
        private Double longitude;
        private int serviceCount;
        private BigDecimal minServicePrice;
        private BigDecimal maxServicePrice;
        private int galleryCount;
        private String acceptedTermsVersion;
        private LocalDateTime termsAcceptedAt;
        /** Admin-only internal note (never sent to the provider). */
        private String verificationNote;
    }

    /** A reported review awaiting moderation. */
    @Data @Builder
    public static class ReviewModerationDto {
        private Long moderationCaseId;
        private Long reviewId;
        private String authorName;
        private String providerName;
        private Integer rating;
        private String comment;
        private String reason;
        private boolean hidden;
        private LocalDateTime createdAt;
    }

    // â”€â”€â”€ Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ServiceDto {
        private Long id;
        private String name;
        private String description;
        private BigDecimal price;
        private Integer durationMinutes;
        private ServiceCategory category;
        private PricingType pricingType;
        private boolean transportIncluded;
        private boolean active;
    }

    // â”€â”€â”€ Availability â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class AvailabilityDto {
        private Long id;
        private Long staffMemberId;
        private DayOfWeek dayOfWeek;
        private LocalTime startTime;
        private LocalTime endTime;
        private Integer slotDurationMinutes;
        private boolean available;
    }

    @Data @Builder
    public static class TimeSlotDto {
        private LocalTime startTime;
        private LocalTime endTime;
        private boolean booked;
    }

    @Data @Builder
    public static class StaffMemberDto {
        private Long id;
        private Long providerId;
        private String fullName;
        private String title;
        private String phone;
        private String skills;
        private boolean active;
        /** Services this staff member performs; empty = all of the provider's services. */
        private List<Long> serviceIds;
    }

    @Data @Builder
    public static class SavedAddressDto {
        private Long id;
        private String label;
        private String addressLine;
        private Double latitude;
        private Double longitude;
        private boolean defaultAddress;
    }

    // â”€â”€â”€ Booking â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class BookingDto {
        private Long id;
        private UserDto customer;
        private ProviderSummaryDto provider;
        private ServiceDto service;
        private LocalDate bookingDate;
        private LocalTime startTime;
        private LocalTime endTime;
        private BookingType bookingType;
        private Integer estimatedArrivalMinutes;
        private StaffMemberDto staffMember;
        private SavedAddressDto savedAddress;
        private boolean homeService;
        private BookingStatus status;
        private PaymentStatus paymentStatus;
        private String paymentMethod;
        private BigDecimal totalPrice;
        /** Home-service travel fee portion of totalPrice; null when no travel fee applies. */
        private BigDecimal travelFee;
        private String notes;
        private String cancellationReason;
        private String cancelledBy;
        private LocalDateTime cancelledAt;
        private String rejectionReason;
        private LocalDate proposedDate;
        private LocalTime proposedStartTime;
        /** The proposed slot lapses at this time if the customer doesn't answer. */
        private LocalDateTime proposalExpiresAt;
        /** Provider's per-booking travel quote and where it stands (PENDING/ACCEPTED/DECLINED). */
        private BigDecimal travelFeeQuote;
        private TravelFeeQuoteStatus travelFeeQuoteStatus;
        /** Provider's note when completing without collecting cash. */
        private String completionNote;
        private boolean penaltyApplied;
        private BigDecimal commissionAmount;
        private LocalDateTime checkedInAt;
        private LocalDateTime createdAt;
        private boolean reviewed;
    }

    /** The other party's phone, released only while a booking is live. */
    @Data @Builder
    public static class BookingContactDto {
        private Long bookingId;
        private String name;
        private String phone;
        /** CUSTOMER or PROVIDER — who this number belongs to. */
        private String role;
    }

    // â”€â”€â”€ Booking with alternatives (reject flow) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class BookingWithAlternativesDto {
        private BookingDto booking;
        private List<ProviderSummaryDto> alternativeProviders;
    }

    // â”€â”€â”€ Review â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ReviewDto {
        private Long id;
        private UserDto user;
        private ProviderSummaryDto provider;
        private Integer rating;
        private String comment;
        private java.util.List<String> quickTags;
        private ReviewDirection direction;
        private boolean hidden;
        private Long bookingId;
        private String serviceName;
        /** Provider's public reply, if any. */
        private String reply;
        private LocalDateTime repliedAt;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class ChatMessageDto {
        private Long id;
        private Long bookingId;
        private UserDto sender;
        private ChatMessageType type;
        private String message;
        private boolean readByRecipient;
        private boolean removed;
        private LocalDateTime createdAt;
    }

    /** One reported chat message awaiting moderation, with the report reason. */
    @Data @Builder
    public static class ChatModerationDto {
        private Long moderationCaseId;
        private Long messageId;
        private Long bookingId;
        private String senderName;
        private String message;
        private String reason;
        private boolean removed;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class SafetyEventDto {
        private Long id;
        private Long bookingId;
        private UserDto actor;
        private SafetyEventType type;
        private Double latitude;
        private Double longitude;
        private String notes;
        private boolean resolved;
        private LocalDateTime resolvedAt;
        private String resolvedByName;
        private String resolutionNotes;
        private LocalDateTime createdAt;
    }

    /** One SOS in the admin safety queue, with enough context to act on it. */
    @Data @Builder
    public static class AdminSafetyEventDto {
        private Long id;
        private Long bookingId;
        private BookingStatus bookingStatus;
        private boolean homeService;
        private String address;
        private Long actorId;
        private String actorName;
        private String actorPhone;
        /** CUSTOMER or PROVIDER — who pressed SOS. */
        private String actorRole;
        private String customerName;
        private String customerPhone;
        private String providerName;
        private String providerPhone;
        private Double latitude;
        private Double longitude;
        private String notes;
        private boolean resolved;
        private LocalDateTime resolvedAt;
        private String resolvedByName;
        private String resolutionNotes;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class TrustedContactDto {
        private Long id;
        private String name;
        private String phone;
        private String relationship;
        private LocalDateTime createdAt;
    }

    /** A gallery photo with its id (provider's own view / moderation). */
    @Data @Builder
    public static class GalleryImageDto {
        private Long id;
        private String url;
        private boolean hidden;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class CommissionLedgerDto {
        private Long id;
        private Long providerId;
        private Long bookingId;
        private BigDecimal bookingAmount;
        private BigDecimal commissionPercent;
        private BigDecimal commissionAmount;
        private LedgerEntryStatus status;
        private LocalDateTime createdAt;
        private LocalDateTime settledAt;
    }

    @Data @Builder
    public static class SettlementSummaryDto {
        private Long providerId;
        /** Outstanding commission not yet overdue (DUE entries). */
        private BigDecimal dueAmount;
        /** Outstanding commission past its due date (OVERDUE entries). */
        private BigDecimal overdueAmount;
        /** Everything still owed (DUE + OVERDUE). */
        private BigDecimal owedAmount;
        /** Owed balance at which new bookings pause until settled. */
        private BigDecimal balanceLimit;
        /** This provider's effective commission rate (override or platform). */
        private BigDecimal commissionPercent;
        /** When the oldest outstanding entry falls due. */
        private LocalDateTime dueDate;
        /** SETTLED | WITHIN_LIMIT | OVERDUE */
        private String status;
        /** Set when the provider has reported paying and finance hasn't confirmed yet. */
        private LocalDateTime paymentReportedAt;
        private boolean settlementPaused;
        private List<CommissionLedgerDto> entries;
    }

    /** Two top cards on the admin Settlements screen. */
    @Data @Builder
    public static class SettlementOverviewDto {
        private BigDecimal commissionPercent;
        private BigDecimal totalOwed;
        private int providerCount;
    }

    /** One row per provider on the admin Settlements table. */
    @Data @Builder
    public static class SettlementRowDto {
        private Long providerId;
        private String providerName;
        /** Effective rate for this provider (override if set, else platform). */
        private BigDecimal commissionPercent;
        /** The provider's custom rate, or null when they use the platform rate. */
        private BigDecimal commissionOverridePercent;
        /** The current platform rate, for reference in the editor. */
        private BigDecimal platformCommissionPercent;
        private BigDecimal grossAmount;
        private BigDecimal balanceOwed;
        private String status;          // WITHIN_LIMIT | OVERDUE | SETTLED
        private boolean settlementPaused;
        /** Provider account suspended (verificationStatus SUSPENDED). */
        private boolean accountSuspended;
        private LocalDateTime dueDate;
        /** The provider tapped "I've paid" at this time; finance hasn't confirmed yet. */
        private LocalDateTime paymentReportedAt;
    }

    /** Per-provider settlement detail: ledger entries + totals. */
    @Data @Builder
    public static class SettlementDetailDto {
        private Long providerId;
        private String providerName;
        private boolean settlementPaused;
        /** Provider account suspended (verificationStatus SUSPENDED). */
        private boolean accountSuspended;
        /** Set while a provider-reported payment waits for finance. */
        private LocalDateTime paymentReportedAt;
        private String status;
        private BigDecimal commissionPercent;
        private BigDecimal commissionOverridePercent;
        private BigDecimal platformCommissionPercent;
        private BigDecimal totalOwed;
        private LocalDateTime dueDate;
        private List<LedgerEntryDto> entries;
    }

    /** Per-provider commission + booking-rule overrides for the provider profile screen. */
    @Data @Builder
    public static class ProviderSettingsDto {
        private Long providerId;
        private String providerName;
        // commission
        private BigDecimal commissionOverridePercent;      // null = using platform
        private BigDecimal effectiveCommissionPercent;
        private BigDecimal platformCommissionPercent;
        // booking rules — overrides (null = using platform) + effective + platform
        private Integer cancellationCutoffHoursOverride;
        private BigDecimal providerCancelPenaltyPercentOverride;
        private Long responseWindowMinutesOverride;
        private Integer effectiveCancellationCutoffHours;
        private BigDecimal effectiveProviderCancelPenaltyPercent;
        private Long effectiveResponseWindowMinutes;
        private Integer platformCancellationCutoffHours;
        private BigDecimal platformProviderCancelPenaltyPercent;
        private Long platformResponseWindowMinutes;
        /** Flat EGP fee added to home-service bookings; null/0 = provider doesn't charge travel. */
        private BigDecimal homeServiceTravelFee;
    }

    @Data @Builder
    public static class LedgerEntryDto {
        private Long id;
        private String serviceName;
        private String customerName;
        private Long bookingId;
        private BigDecimal bookingAmount;
        private BigDecimal commissionPercent;
        private BigDecimal commissionAmount;
        private LedgerEntryStatus status;
        private LocalDateTime createdAt;
        private LocalDateTime settledAt;
    }

    /** Terms/policy version for the admin Policies screen. */
    @Data @Builder
    public static class TermsVersionDto {
        private Long id;
        private String version;
        private String type;
        private String contentEn;
        private boolean active;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class ModerationCaseDto {
        private Long id;
        private ModerationTargetType targetType;
        private Long targetId;
        private String reason;
        private ModerationStatus status;
        private String adminNotes;
        /** For GALLERY_IMAGE cases: the reported photo, so the admin sees it before hiding. */
        private String imageUrl;
        private boolean imageHidden;
        private Long providerId;
        private String providerName;
        private LocalDateTime createdAt;
    }

    // â”€â”€â”€ Notification â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class NotificationDto {
        private Long id;
        private NotificationType type;
        private String titleEn;
        private String titleAr;
        private String bodyEn;
        private String bodyAr;
        private Long relatedBookingId;
        private Long relatedProviderId;
        private boolean read;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class CommissionSettingDto {
        private BigDecimal commissionPercent;
    }

    @Data @Builder
    public static class VerificationCountsDto {
        private long pending;
        private long approved;
        private long rejected;
        private long suspended;
    }

    @Data @Builder
    public static class BookingRulesDto {
        private Integer cancellationCutoffHours;
        private BigDecimal providerCancelPenaltyPercent;
        private Long responseWindowMinutes;
    }

    @Data @Builder
    public static class BookingAnalyticsPointDto {
        private LocalDate date;
        private long completed;
        private long cancelled;
        private long total;
    }

    @Data @Builder
    public static class AuditLogDto {
        private Long id;
        private String actor;
        private String action;
        private String target;
        private String ipAddress;
        private LocalDateTime createdAt;
    }

    /** One row in the admin inbox — a thing that needs attention. */
    @Data @Builder
    public static class InboxItemDto {
        /** Stable id per source ("complaint-123", "verification-45", etc.) so the
         *  frontend can dedupe and remember which the user has already seen. */
        private String id;
        /** COMPLAINT | VERIFICATION | REPORTED_REVIEW | REPORTED_CHAT | DISPUTE */
        private String kind;
        private String title;
        private String body;
        private LocalDateTime createdAt;
        /** Which dashboard route the user should go to on click. */
        private String targetRoute;
    }

    @Data @Builder
    public static class NotificationPreferencesDto {
        private boolean notifyPush;
        private boolean notifyEmail;
        private boolean notifySms;
        private boolean notifyWhatsapp;
        private boolean muteAll;
        private LocalTime quietHoursStart;
        private LocalTime quietHoursEnd;
    }

    // â”€â”€â”€ Complaint â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class ComplaintDto {
        private Long id;
        private String reporterName;
        private String targetProviderName;
        private String targetUserName;
        private Long targetUserId;
        private Long targetProviderId;
        /** The account behind targetProviderId — lets the admin UI warn/act on a
         *  provider through the same user-scoped action it already uses for
         *  customers, without a separate provider-specific endpoint. */
        private Long targetProviderOwnerUserId;
        private Long bookingId;
        private String category;
        private String description;
        private ComplaintStatus status;
        private String adminNotes;
        private boolean flagged;
        /** HIGH / MEDIUM / LOW — derived from flagged + category. */
        private String priority;
        private LocalDateTime createdAt;
    }

    /** Compact activity history for one account, shown on the admin profile screen. */
    @Data @Builder
    public static class UserActivityDto {
        private java.util.List<ActivityBookingDto> bookings;
        private java.util.List<ActivityReviewDto> reviews;
        private java.util.List<ActivityComplaintDto> complaints;
    }

    @Data @Builder
    public static class ActivityBookingDto {
        private Long id;
        private String reference;
        private String counterparty;   // the other party (provider for a customer, customer for a provider)
        private String service;
        private BookingStatus status;
        private PaymentStatus paymentStatus;
        private BigDecimal amount;
        private LocalDate date;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class ActivityReviewDto {
        private Long id;
        private String providerName;
        private Integer rating;
        private String comment;
        private boolean hidden;
        private LocalDateTime createdAt;
    }

    @Data @Builder
    public static class ActivityComplaintDto {
        private Long id;
        private String subject;
        private ComplaintStatus status;
        private boolean flagged;
        private LocalDateTime createdAt;
    }

    // â”€â”€â”€ Support â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class SupportContactDto {
        /** Primary line — mirrors numbers[primary], kept for older app builds. */
        private String whatsappNumber;
        private String whatsappNumberDisplay;
        private String supportEmail;
        private String availabilityHoursEn;
        private String availabilityHoursAr;
        private boolean whatsappEnabled;
        /** All published support lines. Public callers get only the enabled ones. */
        private List<SupportNumberDto> numbers;
    }

    @Data @Builder
    public static class SupportNumberDto {
        private String label;
        private String number;
        private String displayNumber;
        private boolean primary;
        private boolean enabled;
    }

    // â”€â”€â”€ Terms & Policies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class TermsPolicyDto {
        private Long id;
        private String version;
        private String type;
        private String contentEn;
        private String contentAr;
        private String pdfUrl;
        private String changeNote;
        private String publishedBy;
        private boolean active;
        private LocalDateTime createdAt;
    }

    // â”€â”€â”€ Provider Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class DashboardDto {
        private long totalBookings;
        private long pendingBookings;
        private long confirmedBookings;
        private long completedBookings;
        private BigDecimal totalRevenue;
        private Double averageRating;
        /** Published customer reviews (ProviderProfile.totalReviews). */
        private long totalReviews;
        private long totalClients;
        private List<BookingDto> todayBookings;
    }

    // â”€â”€â”€ Admin Dashboard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    @Data @Builder
    public static class AdminDashboardDto {
        private long totalCustomers;
        private long totalProviders;
        private long pendingVerification;
        private long approvedProviders;
        private long rejectedProviders;
        private long suspendedProviders;
        private long totalBookings;
        private long completedBookings;
        private long openComplaints;
        private long openDisputes;
        private long overdueSettlements;
        private BigDecimal totalRevenue;          // SRS FR-019
        /** Unresolved SOS alerts — the safety queue badge. */
        private long openSos;
        // Windowed booking counts (by creation time, Africa/Cairo) for the
        // "Today / 7 days / 30 days with delta" tiles.
        private long bookingsToday;
        private long bookingsLast7Days;
        private long bookingsPrevious7Days;
        private long bookingsLast30Days;
        private long bookingsPrevious30Days;
        private long newCustomersLast30Days;
        private long newCustomersPrevious30Days;
        private long providersVerifiedLast30Days;
        /** Open complaints that are flagged or about safety/payment. */
        private long highPriorityComplaints;
        private BigDecimal revenueLast30Days;
        private BigDecimal revenuePrevious30Days;
    }
}

