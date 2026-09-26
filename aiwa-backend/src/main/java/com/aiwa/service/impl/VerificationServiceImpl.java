package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.ProviderProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class VerificationServiceImpl {

    private final ProviderProfileRepository providerRepo;
    private final NotificationServiceImpl notificationService;

    /** Provider submits identity documents (req 1) */
    @Transactional
    public void submitDocuments(Long userId,
                                String nationalIdFrontPath,
                                String nationalIdBackPath,
                                String selfiePath) {

        ProviderProfile profile = providerRepo.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider profile not found"));

        if (profile.getVerificationStatus() == VerificationStatus.APPROVED) {
            throw new BusinessException("verification.error.already_verified");
        }

        profile.setNationalIdFrontPath(nationalIdFrontPath);
        profile.setNationalIdBackPath(nationalIdBackPath);
        profile.setSelfiePath(selfiePath);
        profile.setVerificationStatus(VerificationStatus.PENDING_VERIFICATION);
        profile.setRejectionReason(null);

        providerRepo.save(profile);
    }

    /** Admin: list all providers pending verification (req 2) */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderVerificationDto> getPendingVerifications(Pageable pageable) {
        return providerRepo.findByVerificationStatus(VerificationStatus.PENDING_VERIFICATION, pageable)
                .map(this::toVerificationDto);
    }

    /** Admin: list providers by any verification status */
    @Transactional(readOnly = true)
    public Page<ApiResponse.ProviderVerificationDto> getByVerificationStatus(
            VerificationStatus status, Pageable pageable) {
        return providerRepo.findByVerificationStatus(status, pageable)
                .map(this::toVerificationDto);
    }

    /** Admin: approve a provider (req 2) */
    @Transactional
    public void approve(Long providerId) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));

        profile.setVerificationStatus(VerificationStatus.APPROVED);
        profile.setRejectionReason(null);
        providerRepo.save(profile);

        notificationService.send(
                profile.getUser().getId(),
                NotificationType.PROVIDER_VERIFICATION_APPROVED,
                "Your profile is approved!",
                "تم قبول ملفك الشخصي!",
                "Congratulations! Your provider profile has been verified. You can now receive bookings.",
                "مبروك! تم التحقق من ملفك كمزود خدمة. يمكنك الآن استقبال الحجوزات.",
                null,
                providerId
        );
    }

    /** Admin: reject a provider with reason (req 2) */
    @Transactional
    public void reject(Long providerId, String reason) {
        if (reason == null || reason.isBlank()) {
            throw new BusinessException("verification.error.reason_required");
        }
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));

        profile.setVerificationStatus(VerificationStatus.REJECTED);
        profile.setRejectionReason(reason);
        providerRepo.save(profile);

        notificationService.send(
                profile.getUser().getId(),
                NotificationType.PROVIDER_VERIFICATION_REJECTED,
                "Profile verification rejected",
                "تم رفض التحقق من ملفك",
                "Your profile was not approved. Reason: " + reason + ". Please resubmit your documents.",
                "لم يتم قبول ملفك. السبب: " + reason + ". يرجى إعادة تقديم المستندات.",
                null,
                providerId
        );
    }

    /** Admin: ask a provider for more information without rejecting them. */
    @Transactional
    public void requestMoreInfo(Long providerId, String message) {
        if (message == null || message.isBlank()) {
            throw new BusinessException("verification.error.info_message_required");
        }
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));

        // Keep the case in the pending queue; record the note without marking rejected.
        profile.setVerificationStatus(VerificationStatus.PENDING_VERIFICATION);
        profile.setRejectionReason(message);
        providerRepo.save(profile);

        notificationService.send(
                profile.getUser().getId(),
                NotificationType.PROVIDER_INFO_REQUESTED,
                "More information needed",
                "مطلوب مزيد من المعلومات",
                "The reviewer needs more information: " + message,
                "يحتاج المراجع إلى مزيد من المعلومات: " + message,
                null,
                providerId
        );
    }

    /** Admin: suspend a provider (req 2) */
    @Transactional
    public void suspend(Long providerId) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        profile.setVerificationStatus(VerificationStatus.SUSPENDED);
        providerRepo.save(profile);

        notificationService.send(
                profile.getUser().getId(),
                NotificationType.PROVIDER_SUSPENDED,
                "Your provider account is suspended",
                "تم إيقاف حساب مزود الخدمة الخاص بك",
                "Your provider profile has been suspended by an administrator. You will not receive new bookings until it is reactivated.",
                "تم إيقاف ملفك كمزود خدمة من قبل الإدارة. لن تستقبل حجوزات جديدة حتى إعادة التفعيل.",
                null,
                providerId
        );
    }

    /** Admin: reactivate a suspended provider (req 2) */
    @Transactional
    public void reactivate(Long providerId) {
        ProviderProfile profile = providerRepo.findById(providerId)
                .orElseThrow(() -> new ResourceNotFoundException("Provider", providerId));
        if (profile.getVerificationStatus() != VerificationStatus.SUSPENDED) {
            throw new BusinessException("verification.error.not_suspended");
        }
        profile.setVerificationStatus(VerificationStatus.APPROVED);
        providerRepo.save(profile);

        notificationService.send(
                profile.getUser().getId(),
                NotificationType.PROVIDER_REACTIVATED,
                "Your provider account is reactivated",
                "تمت إعادة تفعيل حساب مزود الخدمة الخاص بك",
                "Your provider profile has been reactivated. You can now receive bookings again.",
                "تمت إعادة تفعيل ملفك كمزود خدمة. يمكنك الآن استقبال الحجوزات مرة أخرى.",
                null,
                providerId
        );
    }

    private ApiResponse.ProviderVerificationDto toVerificationDto(ProviderProfile p) {
        return ApiResponse.ProviderVerificationDto.builder()
                .id(p.getId())
                .businessName(p.getBusinessName())
                .ownerName(p.getUser().getFullName())
                .ownerEmail(p.getUser().getEmail())
                .ownerPhone(p.getUser().getPhone())
                .primaryCategory(p.getPrimaryCategory())
                .city(p.getAddress())
                .verificationStatus(p.getVerificationStatus())
                .nationalIdFrontPath(p.getNationalIdFrontPath())
                .nationalIdBackPath(p.getNationalIdBackPath())
                .selfiePath(p.getSelfiePath())
                .rejectionReason(p.getRejectionReason())
                .submittedAt(p.getCreatedAt())
                .build();
    }
}
