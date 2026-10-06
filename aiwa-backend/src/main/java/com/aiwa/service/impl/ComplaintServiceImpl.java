package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ComplaintServiceImpl {

    static final String ADMIN_FLAG = "ADMIN_FLAG";

    private final ComplaintRepository complaintRepo;
    private final UserRepository userRepo;
    private final BookingRepository bookingRepo;
    private final ProviderProfileRepository providerRepo;

    @Transactional
    public ApiResponse.ComplaintDto submit(Long reporterId,
                                           Long targetProviderId,
                                           Long bookingId,
                                           String category,
                                           String description) {
        User reporter = userRepo.findById(reporterId)
                .orElseThrow(() -> new ResourceNotFoundException("User", reporterId));

        if (category == null || category.isBlank() || category.length() > 60) {
            throw new BusinessException("complaint.error.category_invalid");
        }
        if (description == null || description.isBlank() || description.length() > 2000) {
            throw new BusinessException("complaint.error.description_invalid");
        }

        ProviderProfile targetProvider = targetProviderId != null
                ? providerRepo.findById(targetProviderId).orElse(null) : null;
        Booking booking = bookingId != null
                ? bookingRepo.findById(bookingId).orElse(null) : null;
        // A complaint may only reference a booking the reporter took part in —
        // otherwise anyone could attach (and have admins read) someone else's booking.
        if (booking != null) {
            boolean party = booking.getCustomer().getId().equals(reporterId)
                    || booking.getProvider().getUser().getId().equals(reporterId);
            if (!party) throw new com.aiwa.exception.ForbiddenException("error.access_denied");
            if (targetProvider == null && booking.getCustomer().getId().equals(reporterId)) {
                targetProvider = booking.getProvider();
            }
        }

        Complaint complaint = Complaint.builder()
                .reporter(reporter)
                .targetProvider(targetProvider)
                .booking(booking)
                .category(category.trim())
                .description(description.trim())
                .status(ComplaintStatus.OPEN)
                .build();

        return toDto(complaintRepo.save(complaint));
    }

    @Transactional(readOnly = true)
    public Page<ApiResponse.ComplaintDto> getMyComplaints(Long userId, Pageable pageable) {
        // Admin flags are internal; older ones were stored with the flagged user as reporter (M-2).
        return complaintRepo.findOwnReports(userId, ADMIN_FLAG, pageable).map(this::toDto);
    }

    /** Admin: view all by status */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ComplaintDto> adminGetAll(ComplaintStatus status, Pageable pageable) {
        return adminSearch(status, null, pageable);
    }

    /** Admin queue, searched and paged on the server (R4 follow-up); {@code query} matches text, category and names. */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ComplaintDto> adminSearch(ComplaintStatus status, String query, Pageable pageable) {
        String q = com.aiwa.util.Searches.pattern(query);
        return (status != null ? complaintRepo.searchByStatus(status, q, pageable) : complaintRepo.searchAll(q, pageable))
                .map(this::toDto);
    }

    /**
     * Admin: resolve a complaint. Also clears {@code flagged} — a resolved
     * complaint (warned, suspended, or dismissed) must drop out of the Flags
     * queue, or it comes right back on the next refresh even though an admin
     * already acted on it, since {@code GET /admin/flags} lists purely by
     * {@code flagged = true} with no regard for status.
     */
    @Transactional
    public ApiResponse.ComplaintDto resolve(Long complaintId, Long adminId, String notes) {
        Complaint c = complaintRepo.findById(complaintId)
                .orElseThrow(() -> new ResourceNotFoundException("Complaint", complaintId));
        c.setStatus(ComplaintStatus.RESOLVED);
        c.setAdminNotes(com.aiwa.dto.request.FreeTextBody.bounded(notes, 2000)); // Complaint.adminNotes
        c.setResolvedByAdminId(adminId);
        c.setFlagged(false);
        return toDto(complaintRepo.save(c));
    }

    /** Admin: flag a user/provider for further review */
    @Transactional
    public void flag(Long complaintId) {
        Complaint c = complaintRepo.findById(complaintId)
                .orElseThrow(() -> new ResourceNotFoundException("Complaint", complaintId));
        c.setFlagged(true);
        c.setStatus(ComplaintStatus.ESCALATED);
        complaintRepo.save(c);
    }

    /**
     * Gap 5: admin directly flags a user. M-2: the acting admin is the reporter.
     * It used to be the flagged user, so the flag and its private reason showed
     * up in that user's own "My reports".
     */
    @Transactional
    public void flagUser(Long adminUserId, Long targetUserId, String reason) {
        User target = userRepo.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", targetUserId));
        User admin = userRepo.findById(adminUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", adminUserId));

        Complaint complaint = Complaint.builder()
                .reporter(admin)
                .targetUser(target)
                .category(ADMIN_FLAG)
                .description(com.aiwa.dto.request.FreeTextBody.bounded(reason, 2000)) // Complaint.description
                .status(ComplaintStatus.ESCALATED)
                .flagged(true)
                .build();
        complaintRepo.save(complaint);
    }

    private ApiResponse.ComplaintDto toDto(Complaint c) {
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
                .priority(priorityOf(c))
                .createdAt(c.getCreatedAt())
                .build();
    }

    /** Admin triage order: escalated, safety and money issues first; "other" last. */
    static String priorityOf(Complaint c) {
        String cat = c.getCategory() == null ? "" : c.getCategory().toUpperCase();
        if (c.isFlagged() || cat.equals("SAFETY") || cat.equals("PAYMENT")) return "HIGH";
        if (cat.equals("OTHER")) return "LOW";
        return "MEDIUM";
    }
}
