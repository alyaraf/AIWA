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
 * coordinates (and the destination on their bookings), a provider's listing address,
 * coordinates and bio, trusted contacts, a provider's ID documents and selfie, gallery
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

    /** CR-02: V19's {@code identifier_collisions} has no entity; it keeps raw emails and phones. */
    @org.springframework.beans.factory.annotation.Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbc; // null only when a unit test builds the service by hand

    /**
     * CR-10 / M-4 (owner rule 2026-10-04): a user can't close their own account while a
     * booking is live (accepted through in progress, as customer or provider) or while
     * commission is still owed. The message says what to finish first. Support's
     * deletion (DELETE /admin/users/{id}) is a deliberate override and doesn't call this.
     *
     * <p>AP-01: an admin account is never closed this way. Closed from the app, the last super admin's
     * deletion left no active super admin, and every admin could then create super admins (the
     * bootstrap rule in AdminUsersController). A super admin removes admins with DELETE /admin/users/{id},
     * which keeps at least one active super admin.</p>
     */
    @Transactional(readOnly = true)
    public void requireSelfDeletable(User user) {
        if (user.getRole() == com.aiwa.enums.UserRole.ADMIN) {
            throw new com.aiwa.exception.ConflictException("account.error.admin_self_delete");
        }
        java.util.Set<BookingStatus> live = BookingServiceImpl.CONTACT_VISIBLE;
        boolean liveAsCustomer = live.stream()
                .anyMatch(st -> !bookingRepo.findByCustomerIdAndStatus(user.getId(), st).isEmpty());
        var profile = providerRepo.findByUserId(user.getId());
        boolean liveAsProvider = profile.isPresent()
                && !bookingRepo.findByProviderIdAndStatusIn(profile.get().getId(), live).isEmpty();
        if (liveAsCustomer || liveAsProvider) {
            throw new com.aiwa.exception.ConflictException("account.error.delete_live_bookings");
        }
        if (profile.isPresent() && ledgerRepo != null && !ledgerRepo.findByProviderIdAndStatusIn(profile.get().getId(),
                List.of(com.aiwa.enums.LedgerEntryStatus.DUE, com.aiwa.enums.LedgerEntryStatus.OVERDUE)).isEmpty()) {
            throw new com.aiwa.exception.ConflictException("account.error.delete_commission_owed");
        }
    }

    /**
     * SA-11: support's deletion is an override for ordinary bookings (they are cancelled), but a
     * visit that is already under way cannot just be cancelled around the other person. It is
     * refused until the visit ends or someone resolves it.
     */
    @Transactional(readOnly = true)
    public void requireNoLiveVisit(User user) {
        List<BookingStatus> visit = List.of(BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS);
        boolean asCustomer = visit.stream()
                .anyMatch(st -> !bookingRepo.findByCustomerIdAndStatus(user.getId(), st).isEmpty());
        var profile = providerRepo.findByUserId(user.getId());
        boolean asProvider = profile.isPresent()
                && !bookingRepo.findByProviderIdAndStatusIn(profile.get().getId(), visit).isEmpty();
        if (asCustomer || asProvider) {
            throw new com.aiwa.exception.ConflictException("admin.error.delete_live_visit");
        }
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    private com.aiwa.repository.CommissionLedgerRepository ledgerRepo;

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

        // RV-02: a booking's destination is the customer's address too. The booking stays, the place goes.
        bookingRepo.findByCustomerId(user.getId()).forEach(b -> {
            b.setDestinationLabel(null);
            b.setDestinationAddress(null);
            b.setDestinationLatitude(null);
            b.setDestinationLongitude(null);
            bookingRepo.save(b);
        });

        // Files go only after the commit, so a rollback never leaves rows pointing at deleted files.
        List<String> publicFiles = new java.util.ArrayList<>();
        List<String> privateFiles = new java.util.ArrayList<>();

        providerRepo.findByUserId(user.getId()).ifPresent(profile -> {
            profile.setVerificationStatus(VerificationStatus.SUSPENDED);
            profile.setOfflineMode(true);
            // RV-02: for a home-based provider the listing's address is their home.
            profile.setAddress(null);
            profile.setLatitude(null);
            profile.setLongitude(null);
            profile.setBio(null);
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
        user.setTotpPendingSecret(null);
        user.setTotpEnabled(false);
        user.setSearchAreaLabel(null);
        user.setSearchAreaLatitude(null);
        user.setSearchAreaLongitude(null);
        user.setActive(false);
        user.setTokensValidAfter(Instant.now());
        userRepo.save(user);
        scrubIdentifierCollisions(user.getId());

        afterCommit(() -> {
            publicFiles.forEach(fileStorage::deletePublic);
            privateFiles.forEach(fileStorage::deletePrivate);
        });
    }

    /**
     * V19 parks the raw email/phone of an account it could not normalise in {@code identifier_collisions}, for a
     * person to resolve. Once either account of a pair is deleted those values must not outlive it. The table only
     * exists where Flyway ran, so a database without it (dev, tests) is skipped instead of failing the deletion.
     */
    private void scrubIdentifierCollisions(Long userId) {
        if (jdbc == null) return;
        boolean exists = Boolean.TRUE.equals(jdbc.execute((java.sql.Connection c) -> {
            try (java.sql.ResultSet rs = c.getMetaData().getTables(null, null, "%", new String[]{"TABLE"})) {
                while (rs.next()) if ("identifier_collisions".equalsIgnoreCase(rs.getString("TABLE_NAME"))) return true;
                return false;
            }
        }));
        if (exists) {
            jdbc.update("DELETE FROM identifier_collisions WHERE user_id = ? OR conflicts_with_user_id = ?", userId, userId);
        }
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
