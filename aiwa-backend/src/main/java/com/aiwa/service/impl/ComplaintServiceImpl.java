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
        return complaintRepo.findByReporterIdOrderByCreatedAtDesc(userId, pageable).map(this::toDto);
    }

    /** Admin: view all by status */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ComplaintDto> adminGetAll(ComplaintStatus status, Pageable pageable) {
        if (status != null) {
            return complaintRepo.findByStatusOrderByCreatedAtDesc(status, pageable).map(this::toDto);
        }
        return complaintRepo.findAll(pageable).map(this::toDto);
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
        c.setAdminNotes(notes);
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

    /** Gap 5: admin directly flags a user */
    @Transactional
    public void flagUser(Long targetUserId, String reason) {
        User target = userRepo.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", targetUserId));

        Complaint complaint = Complaint.builder()
                .reporter(target) // self-report placeholder
                .targetUser(target)
                .category("ADMIN_FLAG")
                .description(reason)
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
                .createdAt(c.getCreatedAt())
                .build();
    }
}
