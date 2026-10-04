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
    static final int MAX_ADDRESSES = 20;

    private final UserRepository userRepo;
    private final SavedAddressRepository addressRepo;
    private final BookingRepository bookingRepo;
    private final TrustedContactRepository trustedContactRepo;
    private final ProviderProfileRepository providerRepo;
    private final NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AccountDeletionService accountDeletion;
    private final com.aiwa.service.impl.AuthServiceImpl authService;

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
        int existing = addressRepo.findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc(user.getId()).size();
        if (existing >= MAX_ADDRESSES) { // L-13: the list was unbounded
            throw new BusinessException("account.error.addresses_limit");
        }
        boolean first = existing == 0;
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
        // L-13: stored in E.164 like account phones, so the SOS text reaches the gateway in a form it accepts.
        String phone = com.aiwa.util.Identifiers.normalizePhone(request.getPhone());
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
     * Anonymise and disable the account; see {@link com.aiwa.service.impl.AccountDeletionService}.
     */
    @DeleteMapping
    @Operation(summary = "Close your account — needs {currentPassword} in the body")
    public ResponseEntity<ApiResponse.Success<Void>> deleteAccount(
            @RequestBody(required = false) com.aiwa.dto.request.AuthRequest.CurrentPassword request,
            @AuthenticationPrincipal UserDetails userDetails) {
        // CR-05: a session alone (a borrowed phone, a stolen token) cannot close the
        // account. Here and not in AccountDeletionService: support's deletion
        // (DELETE /admin/users/{id}) goes through that too and has no user password.
        authService.confirmPassword(userDetails.getUsername(), request == null ? null : request.getCurrentPassword());
        User me = resolveUser(userDetails);
        accountDeletion.requireSelfDeletable(me); // CR-10
        accountDeletion.delete(me);
        return ResponseEntity.ok(ApiResponse.Success.of("Account deleted", null));
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByLogin(ud.getUsername())
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
