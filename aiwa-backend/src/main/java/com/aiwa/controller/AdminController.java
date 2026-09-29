package com.aiwa.controller;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.Booking;
import com.aiwa.entity.Complaint;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.SavedAddress;
import com.aiwa.entity.StaffMember;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin", description = "Admin-only platform statistics and management")
public class AdminController {

    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;
    private final BookingRepository bookingRepo;
    private final ComplaintRepository complaintRepo;
    private final ReviewRepository reviewRepo;
    private final CommissionLedgerRepository ledgerRepo;
    private final SafetyEventRepository safetyRepo;

    @GetMapping("/dashboard")
    @Operation(summary = "Platform dashboard stats (ADMIN) - FR-019")
    public ResponseEntity<ApiResponse.Success<ApiResponse.AdminDashboardDto>> dashboard() {

        long totalCustomers   = userRepo.countByRole(UserRole.CUSTOMER);
        long totalProviders   = userRepo.countByRole(UserRole.PROVIDER);
        long pendingVerif     = providerRepo.countByVerificationStatus(VerificationStatus.PENDING_VERIFICATION);
        long approvedVerif    = providerRepo.countByVerificationStatus(VerificationStatus.APPROVED);
        long rejectedVerif    = providerRepo.countByVerificationStatus(VerificationStatus.REJECTED);
        long suspendedVerif   = providerRepo.countByVerificationStatus(VerificationStatus.SUSPENDED);
        long totalBookings    = bookingRepo.count();
        long completedBookings = bookingRepo.countByStatus(BookingStatus.COMPLETED);
        long openComplaints   = complaintRepo.countByStatus(ComplaintStatus.OPEN);
        long openDisputes     = bookingRepo.countByPaymentStatus(com.aiwa.enums.PaymentStatus.DISPUTED);
        long overdueSettlements = ledgerRepo.countDistinctProvidersByStatus(com.aiwa.enums.LedgerEntryStatus.OVERDUE);

        BigDecimal totalRevenue = bookingRepo.sumRevenueByStatus(BookingStatus.COMPLETED);
        if (totalRevenue == null) totalRevenue = BigDecimal.ZERO;

        ApiResponse.AdminDashboardDto dto = ApiResponse.AdminDashboardDto.builder()
                .totalCustomers(totalCustomers)
                .totalProviders(totalProviders)
                .pendingVerification(pendingVerif)
                .approvedProviders(approvedVerif)
                .rejectedProviders(rejectedVerif)
                .suspendedProviders(suspendedVerif)
                .totalBookings(totalBookings)
                .completedBookings(completedBookings)
                .openComplaints(openComplaints)
                .openDisputes(openDisputes)
                .overdueSettlements(overdueSettlements)
                .totalRevenue(totalRevenue)
                .build();

        java.time.LocalDateTime now = com.aiwa.util.AiwaTime.now();
        java.time.LocalDateTime startOfToday = com.aiwa.util.AiwaTime.today().atStartOfDay();
        dto.setOpenSos(safetyRepo.countByTypeAndResolvedFalse(com.aiwa.enums.SafetyEventType.SOS));
        dto.setBookingsToday(bookingRepo.countByCreatedAtBetween(startOfToday, now));
        dto.setBookingsLast7Days(bookingRepo.countByCreatedAtBetween(now.minusDays(7), now));
        dto.setBookingsPrevious7Days(bookingRepo.countByCreatedAtBetween(now.minusDays(14), now.minusDays(7)));
        dto.setBookingsLast30Days(bookingRepo.countByCreatedAtBetween(now.minusDays(30), now));
        dto.setBookingsPrevious30Days(bookingRepo.countByCreatedAtBetween(now.minusDays(60), now.minusDays(30)));
        dto.setNewCustomersLast30Days(userRepo.countByRoleAndCreatedAtBetween(UserRole.CUSTOMER, now.minusDays(30), now));
        dto.setNewCustomersPrevious30Days(userRepo.countByRoleAndCreatedAtBetween(
                UserRole.CUSTOMER, now.minusDays(60), now.minusDays(30)));

        return ResponseEntity.ok(ApiResponse.Success.of(dto));
    }

    @GetMapping("/bookings")
    @Operation(summary = "List all bookings for admin monitoring")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> bookings(
            @RequestParam(required = false) BookingStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Booking> bookings = status != null
                ? bookingRepo.findByStatusOrderByCreatedAtDesc(status, pageable)
                : bookingRepo.findAllByOrderByCreatedAtDesc(pageable);
        // Materialise DTOs inside the transaction — open-in-view is off.
        List<ApiResponse.BookingDto> dtos = bookings.getContent().stream().map(this::toBookingDto).toList();
        return ResponseEntity.ok(ApiResponse.Success.of(new PageImpl<>(dtos, pageable, bookings.getTotalElements())));
    }

    @GetMapping("/reviews")
    @Operation(summary = "List all reviews for admin moderation")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> reviews(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Review> reviews = reviewRepo.findAllByOrderByCreatedAtDesc(pageable);
        List<ApiResponse.ReviewDto> dtos = reviews.getContent().stream().map(this::toReviewDto).toList();
        return ResponseEntity.ok(ApiResponse.Success.of(new PageImpl<>(dtos, pageable, reviews.getTotalElements())));
    }

    @GetMapping("/flags")
    @Operation(summary = "List flagged complaints for admin review")
    @Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> flags(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<Complaint> flags = complaintRepo.findByFlaggedTrueOrderByCreatedAtDesc(pageable);
        List<ApiResponse.ComplaintDto> dtos = flags.getContent().stream().map(this::toComplaintDto).toList();
        return ResponseEntity.ok(ApiResponse.Success.of(new PageImpl<>(dtos, pageable, flags.getTotalElements())));
    }

    private ApiResponse.BookingDto toBookingDto(Booking b) {
        return ApiResponse.BookingDto.builder()
                .id(b.getId())
                .customer(toUserDto(b.getCustomer()))
                .provider(toProviderSummary(b.getProvider()))
                .service(toServiceDto(b.getService()))
                .bookingDate(b.getBookingDate())
                .startTime(b.getStartTime())
                .endTime(b.getEndTime())
                .bookingType(b.getBookingType())
                .estimatedArrivalMinutes(b.getEstimatedArrivalMinutes())
                .staffMember(b.getStaffMember() != null ? toStaffDto(b.getStaffMember()) : null)
                .savedAddress(b.getSavedAddress() != null ? toAddressDto(b.getSavedAddress()) : null)
                .homeService(b.isHomeService())
                .status(b.getStatus())
                .paymentStatus(b.getPaymentStatus())
                .paymentMethod(b.getPaymentMethod())
                .totalPrice(b.getTotalPrice())
                .notes(b.getNotes())
                .cancellationReason(b.getCancellationReason())
                .cancelledBy(b.getCancelledBy())
                .cancelledAt(b.getCancelledAt())
                .rejectionReason(b.getRejectionReason())
                .createdAt(b.getCreatedAt())
                .reviewed(b.getReviews() != null && !b.getReviews().isEmpty())
                .build();
    }

    private ApiResponse.ReviewDto toReviewDto(Review r) {
        return ApiResponse.ReviewDto.builder()
                .id(r.getId())
                .user(toUserDto(r.getUser()))
                .provider(toProviderSummary(r.getProvider()))
                .rating(r.getRating())
                .comment(r.getComment())
                .quickTags(r.getQuickTags())
                .direction(r.getDirection())
                .hidden(r.isHidden())
                .createdAt(r.getCreatedAt())
                .build();
    }

    private ApiResponse.ComplaintDto toComplaintDto(Complaint c) {
        return ApiResponse.ComplaintDto.builder()
                .id(c.getId())
                .reporterName(c.getReporter().getFullName())
                .targetProviderName(c.getTargetProvider() != null ? c.getTargetProvider().getBusinessName() : null)
                .targetUserName(c.getTargetUser() != null ? c.getTargetUser().getFullName() : null)
                .targetUserId(c.getTargetUser() != null ? c.getTargetUser().getId() : null)
                .targetProviderId(c.getTargetProvider() != null ? c.getTargetProvider().getId() : null)
                .targetProviderOwnerUserId(c.getTargetProvider() != null && c.getTargetProvider().getUser() != null
                        ? c.getTargetProvider().getUser().getId() : null)
                .bookingId(c.getBooking() != null ? c.getBooking().getId() : null)
                .category(c.getCategory())
                .description(c.getDescription())
                .status(c.getStatus())
                .adminNotes(c.getAdminNotes())
                .flagged(c.isFlagged())
                .createdAt(c.getCreatedAt())
                .build();
    }

    private ApiResponse.UserDto toUserDto(User u) {
        return ApiResponse.UserDto.builder()
                .id(u.getId())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .preferredLanguage(u.getPreferredLanguage())
                .termsAccepted(u.isTermsAccepted())
                .active(u.isActive())
                .permissions(u.getAdminPermissions() == null ? java.util.List.of()
                        : u.getAdminPermissions().stream().map(Enum::name).sorted().toList())
                .createdAt(u.getCreatedAt())
                .build();
    }

    private ApiResponse.ProviderSummaryDto toProviderSummary(ProviderProfile p) {
        return ApiResponse.ProviderSummaryDto.builder()
                .id(p.getId())
                .businessName(p.getBusinessName())
                .address(p.getAddress())
                .latitude(p.getLatitude())
                .longitude(p.getLongitude())
                .primaryCategory(p.getPrimaryCategory())
                .averageRating(p.getAverageRating())
                .totalReviews(p.getTotalReviews())
                .verificationStatus(p.getVerificationStatus())
                .ownerName(p.getUser() != null ? p.getUser().getFullName() : null)
                .profileImageUrl(p.getUser() != null ? p.getUser().getProfileImageUrl() : null)
                .providerType(p.getProviderType())
                .vacationMode(p.isVacationMode())
                .offlineMode(p.isOfflineMode())
                .settlementPaused(p.isSettlementPaused())
                .build();
    }

    private ApiResponse.ServiceDto toServiceDto(com.aiwa.entity.Service s) {
        return ApiResponse.ServiceDto.builder()
                .id(s.getId())
                .name(s.getName())
                .description(s.getDescription())
                .price(s.getPrice())
                .durationMinutes(s.getDurationMinutes())
                .category(s.getCategory())
                .pricingType(s.getPricingType())
                .transportIncluded(s.isTransportIncluded())
                .active(s.isActive())
                .build();
    }

    private ApiResponse.StaffMemberDto toStaffDto(StaffMember s) {
        return ApiResponse.StaffMemberDto.builder()
                .id(s.getId())
                .providerId(s.getProvider().getId())
                .fullName(s.getFullName())
                .title(s.getTitle())
                .phone(s.getPhone())
                .active(s.isActive())
                .build();
    }

    private ApiResponse.SavedAddressDto toAddressDto(SavedAddress a) {
        return ApiResponse.SavedAddressDto.builder()
                .id(a.getId())
                .label(a.getLabel())
                .addressLine(a.getAddressLine())
                .latitude(a.getLatitude())
                .longitude(a.getLongitude())
                .defaultAddress(a.isDefaultAddress())
                .build();
    }
}
