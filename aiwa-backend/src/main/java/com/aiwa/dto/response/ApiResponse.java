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
        private boolean active;
        private java.util.List<String> permissions;
        private Long providerProfileId;
        private VerificationStatus providerStatus;
        private Long bookingCount;
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
        private Double distanceKm;
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
        private boolean penaltyApplied;
        private BigDecimal commissionAmount;
        private LocalDateTime checkedInAt;
        private LocalDateTime createdAt;
        private boolean reviewed;
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
        private BigDecimal dueAmount;
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
        private LocalDateTime dueDate;
    }

    /** Per-provider settlement detail: ledger entries + totals. */
    @Data @Builder
    public static class SettlementDetailDto {
        private Long providerId;
        private String providerName;
        private boolean settlementPaused;
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
    }
}

