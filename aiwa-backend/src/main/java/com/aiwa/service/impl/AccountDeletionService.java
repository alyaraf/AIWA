package com.aiwa.service.impl;

import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Closing an account, from the app (DELETE /account) or by support on a
 * deletion request (DELETE /admin/users/{id}). One place, so both keep the
 * promises on the public deletion page and in the privacy policy (OPS-4).
 *
 * <p>Anonymises and disables the user; for a provider also takes the listing
 * down and cancels their open bookings. Erases saved addresses and their
 * coordinates, trusted contacts, a provider's ID documents and selfie, gallery
 * photos and the avatar. Past bookings, reviews, chats and ledger rows stay
 * (disputes and accounting need them) under "Deleted user".
 */
@Service
@RequiredArgsConstructor
public class AccountDeletionService {

    private final UserRepository userRepo;
    private final SavedAddressRepository addressRepo;
    private final BookingRepository bookingRepo;
    private final TrustedContactRepository trustedContactRepo;
    private final ProviderProfileRepository providerRepo;
    private final NotificationServiceImpl notificationService;
    private final FileStorageServiceImpl fileStorage;
    private final GalleryImageRepository galleryRepo;
    private final com.aiwa.repository.PushDeviceRepository pushDeviceRepo;

    @Transactional
    public void delete(User user) {
        LocalDateTime now = LocalDateTime.now();

        // Cancel any still-active bookings the customer holds.
        for (BookingStatus st : List.of(BookingStatus.PENDING, BookingStatus.ACCEPTED)) {
            bookingRepo.findByCustomerIdAndStatus(user.getId(), st).forEach(b -> {
                b.setStatus(BookingStatus.CANCELLED);
                b.setCancelledBy("CUSTOMER");
                b.setCancellationReason("Account deleted");
                b.setCancelledAt(now);
                bookingRepo.save(b);
                notificationService.send(b.getProvider().getUser().getId(), NotificationType.BOOKING_CANCELLED,
                        "Booking cancelled", "تم إلغاء الحجز",
                        "A customer closed their account; booking #" + b.getId() + " was cancelled.",
                        "أغلق أحد العملاء حسابه وتم إلغاء الحجز رقم " + b.getId() + ".",
                        b.getId(), b.getProvider().getId());
            });
        }

        // Files go only after the commit, so a rollback never leaves rows pointing at deleted files.
        List<String> publicFiles = new java.util.ArrayList<>();
        List<String> privateFiles = new java.util.ArrayList<>();

        providerRepo.findByUserId(user.getId()).ifPresent(profile -> {
            profile.setVerificationStatus(VerificationStatus.SUSPENDED);
            profile.setOfflineMode(true);
            java.util.stream.Stream.of(profile.getNationalIdFrontPath(), profile.getNationalIdBackPath(), profile.getSelfiePath())
                    .filter(java.util.Objects::nonNull).forEach(privateFiles::add);
            profile.setNationalIdFrontPath(null);
            profile.setNationalIdBackPath(null);
            profile.setSelfiePath(null);
            var gallery = galleryRepo.findByProviderIdOrderByIdAsc(profile.getId());
            gallery.forEach(g -> publicFiles.add(g.getUrl()));
            profile.getGallery().removeAll(gallery);
            galleryRepo.deleteAll(gallery);
            providerRepo.save(profile);
            bookingRepo.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc(profile.getId(),
                            List.of(BookingStatus.PENDING, BookingStatus.ACCEPTED),
                            org.springframework.data.domain.Pageable.unpaged())
                    .forEach(b -> {
                        b.setStatus(BookingStatus.CANCELLED);
                        b.setCancelledBy("PROVIDER");
                        b.setCancellationReason("Provider account closed");
                        b.setCancelledAt(now);
                        bookingRepo.save(b);
                        notificationService.send(b.getCustomer().getId(), NotificationType.BOOKING_CANCELLED,
                                "Booking cancelled", "تم إلغاء الحجز",
                                "Your booking for " + b.getService().getName()
                                        + " was cancelled because the provider closed their account.",
                                "تم إلغاء حجزك لـ " + b.getService().getName() + " لأن مقدم الخدمة أغلق حسابه.",
                                b.getId(), profile.getId());
                    });
        });

        trustedContactRepo.deleteAll(trustedContactRepo.findByUserIdOrderByCreatedAtAsc(user.getId()));

        addressRepo.findByUserId(user.getId()).forEach(a -> {
            a.setLabel("Deleted");
            a.setAddressLine("Deleted");
            a.setLatitude(null);
            a.setLongitude(null);
            a.setDefaultAddress(false);
            a.setArchived(true);
            addressRepo.save(a);
        });
        if (user.getProfileImageUrl() != null) publicFiles.add(user.getProfileImageUrl());

        // Anonymize personal data and disable the account (soft-delete + GDPR-style scrub).
        user.setFullName("Deleted user");
        user.setEmail(null);
        user.setPendingEmail(null);
        user.setPhone(null);
        user.setProfileImageUrl(null);
        user.setPushToken(null);
        user.setPushPlatform(null);
        pushDeviceRepo.deleteByUserId(user.getId());
        user.setTotpSecret(null);
        user.setTotpEnabled(false);
        user.setSearchAreaLabel(null);
        user.setSearchAreaLatitude(null);
        user.setSearchAreaLongitude(null);
        user.setActive(false);
        user.setTokensValidAfter(Instant.now());
        userRepo.save(user);

        afterCommit(() -> {
            publicFiles.forEach(fileStorage::deletePublic);
            privateFiles.forEach(fileStorage::deletePrivate);
        });
    }

    private static void afterCommit(Runnable task) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { task.run(); }
            });
        } else {
            task.run();
        }
    }
}
