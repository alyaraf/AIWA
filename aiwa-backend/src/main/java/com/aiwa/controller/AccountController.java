package com.aiwa.controller;

import com.aiwa.dto.request.SavedAddressRequest;
import com.aiwa.dto.request.TrustedContactRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.NotificationServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/account")
@RequiredArgsConstructor
@Tag(name = "Account", description = "Saved addresses, trusted contacts and account deletion")
public class AccountController {

    static final int MAX_TRUSTED_CONTACTS = 5;

    private final UserRepository userRepo;
    private final SavedAddressRepository addressRepo;
    private final BookingRepository bookingRepo;
    private final TrustedContactRepository trustedContactRepo;
    private final ProviderProfileRepository providerRepo;
    private final NotificationServiceImpl notificationService;

    // ── Saved addresses ──────────────────────────────────────────────────────

    @GetMapping("/addresses")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.SavedAddressDto>>> addresses(
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of(addressRepo
                .findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc(userId)
                .stream().map(this::toDto).toList()));
    }

    @PostMapping("/addresses")
    @Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.SavedAddressDto>> addAddress(
            @Valid @RequestBody SavedAddressRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        // The first address becomes the default automatically.
        boolean first = addressRepo.findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc(user.getId()).isEmpty();
        SavedAddress address = addressRepo.save(SavedAddress.builder()
                .user(user)
                .label(request.getLabel().trim())
                .addressLine(request.getAddressLine().trim())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .defaultAddress(first || Boolean.TRUE.equals(request.getDefaultAddress()))
                .build());
        if (address.isDefaultAddress()) {
            addressRepo.clearDefaultExcept(user.getId(), address.getId());
        }
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Address saved", toDto(address)));
    }

    @PutMapping("/addresses/{id}")
    @Transactional
    @Operation(summary = "Edit one of your saved addresses (defaultAddress=true makes it the only default)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SavedAddressDto>> updateAddress(
            @PathVariable Long id,
            @Valid @RequestBody SavedAddressRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        SavedAddress address = ownAddress(id, userId);
        address.setLabel(request.getLabel().trim());
        address.setAddressLine(request.getAddressLine().trim());
        // No coordinates in the request = keep the saved pin (the edit form only
        // sends them when the user dropped a new one).
        if (request.getLatitude() != null || request.getLongitude() != null) {
            address.setLatitude(request.getLatitude());
            address.setLongitude(request.getLongitude());
        }
        if (request.getDefaultAddress() != null) {
            address.setDefaultAddress(request.getDefaultAddress());
        }
        SavedAddress saved = addressRepo.save(address);
        if (saved.isDefaultAddress()) {
            addressRepo.clearDefaultExcept(userId, saved.getId());
        }
        return ResponseEntity.ok(ApiResponse.Success.of("Address updated", toDto(saved)));
    }

    @DeleteMapping("/addresses/{id}")
    @Transactional
    public ResponseEntity<ApiResponse.Success<Void>> deleteAddress(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        SavedAddress address = ownAddress(id, userId);
        if (bookingRepo.existsBySavedAddressId(address.getId())) {
            // Past bookings still reference it (a hard delete failed on the foreign
            // key) — hide it from the list instead.
            address.setArchived(true);
            address.setDefaultAddress(false);
            addressRepo.save(address);
        } else {
            addressRepo.delete(address);
        }
        return ResponseEntity.ok(ApiResponse.Success.of("Address deleted", null));
    }

    private SavedAddress ownAddress(Long id, Long userId) {
        SavedAddress address = addressRepo.findById(id)
                .filter(a -> !a.isArchived())
                .orElseThrow(() -> new ResourceNotFoundException("Saved address", id));
        if (!address.getUser().getId().equals(userId)) {
            // 404 rather than 403 so ids of other users' addresses can't be probed.
            throw new ResourceNotFoundException("Saved address", id);
        }
        return address;
    }

    // ── Trusted contacts (texted when you press SOS) ─────────────────────────

    @GetMapping("/trusted-contacts")
    @Operation(summary = "People who get an SMS when you trigger an SOS")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.TrustedContactDto>>> trustedContacts(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.Success.of(trustedContactRepo
                .findByUserIdOrderByCreatedAtAsc(resolveUserId(userDetails))
                .stream().map(AccountController::toDto).toList()));
    }

    @PostMapping("/trusted-contacts")
    @Transactional
    @Operation(summary = "Add a trusted contact (up to 5)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.TrustedContactDto>> addTrustedContact(
            @Valid @RequestBody TrustedContactRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        if (trustedContactRepo.countByUserId(user.getId()) >= MAX_TRUSTED_CONTACTS) {
            throw new BusinessException("account.error.trusted_contacts_limit");
        }
        String phone = request.getPhone().replaceAll("[ \\-]", "");
        if (phone.equals(user.getPhone())) {
            throw new BusinessException("account.error.trusted_contact_self");
        }
        TrustedContact saved = trustedContactRepo.save(TrustedContact.builder()
                .user(user)
                .name(request.getName().trim())
                .phone(phone)
                .relationship(request.getRelationship() == null || request.getRelationship().isBlank()
                        ? null : request.getRelationship().trim())
                .build());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Trusted contact added", toDto(saved)));
    }

    @DeleteMapping("/trusted-contacts/{id}")
    @Transactional
    public ResponseEntity<ApiResponse.Success<Void>> removeTrustedContact(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        TrustedContact contact = trustedContactRepo.findById(id)
                .filter(c -> c.getUser().getId().equals(userId))
                .orElseThrow(() -> new ResourceNotFoundException("Trusted contact", id));
        trustedContactRepo.delete(contact);
        return ResponseEntity.ok(ApiResponse.Success.of("Trusted contact removed", null));
    }

    // ── Account deletion ─────────────────────────────────────────────────────

    /**
     * Anonymise and disable the account. For a provider this also takes the
     * listing down and cancels their open bookings (before, a deleted provider
     * stayed APPROVED and bookable with a "Deleted user" owner).
     */
    @DeleteMapping
    @Transactional
    public ResponseEntity<ApiResponse.Success<Void>> deleteAccount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
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

        providerRepo.findByUserId(user.getId()).ifPresent(profile -> {
            profile.setVerificationStatus(VerificationStatus.SUSPENDED);
            profile.setOfflineMode(true);
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

        // Anonymize personal data and disable the account (soft-delete + GDPR-style scrub).
        user.setFullName("Deleted user");
        user.setEmail(null);
        user.setPhone(null);
        user.setProfileImageUrl(null);
        user.setPushToken(null);
        user.setPushPlatform(null);
        user.setTotpSecret(null);
        user.setTotpEnabled(false);
        user.setSearchAreaLabel(null);
        user.setSearchAreaLatitude(null);
        user.setSearchAreaLongitude(null);
        user.setActive(false);
        user.setTokensValidAfter(Instant.now());
        userRepo.save(user);

        return ResponseEntity.ok(ApiResponse.Success.of("Account deleted", null));
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow();
    }

    private Long resolveUserId(UserDetails ud) {
        Long id = com.aiwa.security.AiwaUserDetails.idOf(ud);
        if (id != null) return id;
        return resolveUser(ud).getId();
    }

    private ApiResponse.SavedAddressDto toDto(SavedAddress a) {
        return ApiResponse.SavedAddressDto.builder()
                .id(a.getId())
                .label(a.getLabel())
                .addressLine(a.getAddressLine())
                .latitude(a.getLatitude())
                .longitude(a.getLongitude())
                .defaultAddress(a.isDefaultAddress())
                .build();
    }

    private static ApiResponse.TrustedContactDto toDto(TrustedContact c) {
        return ApiResponse.TrustedContactDto.builder()
                .id(c.getId())
                .name(c.getName())
                .phone(c.getPhone())
                .relationship(c.getRelationship())
                .createdAt(c.getCreatedAt())
                .build();
    }
}
