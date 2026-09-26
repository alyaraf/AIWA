package com.aiwa.controller;

import com.aiwa.dto.request.SavedAddressRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.*;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/account")
@RequiredArgsConstructor
public class AccountController {

    private final UserRepository userRepo;
    private final SavedAddressRepository addressRepo;
    private final BookingRepository bookingRepo;

    @GetMapping("/addresses")
    public ResponseEntity<ApiResponse.Success<List<ApiResponse.SavedAddressDto>>> addresses(
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        return ResponseEntity.ok(ApiResponse.Success.of(addressRepo
                .findByUserIdOrderByDefaultAddressDescCreatedAtDesc(userId)
                .stream().map(this::toDto).toList()));
    }

    @PostMapping("/addresses")
    public ResponseEntity<ApiResponse.Success<ApiResponse.SavedAddressDto>> addAddress(
            @Valid @RequestBody SavedAddressRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);
        SavedAddress address = SavedAddress.builder()
                .user(user)
                .label(request.getLabel())
                .addressLine(request.getAddressLine())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .defaultAddress(Boolean.TRUE.equals(request.getDefaultAddress()))
                .build();
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Address saved", toDto(addressRepo.save(address))));
    }

    @DeleteMapping("/addresses/{id}")
    public ResponseEntity<ApiResponse.Success<Void>> deleteAddress(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        Long userId = resolveUserId(userDetails);
        SavedAddress address = addressRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Saved address", id));
        if (!address.getUser().getId().equals(userId)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.Success.of("Address does not belong to user", null));
        }
        addressRepo.delete(address);
        return ResponseEntity.ok(ApiResponse.Success.of("Address deleted", null));
    }

    @DeleteMapping
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<Void>> deleteAccount(
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = resolveUser(userDetails);

        // Cancel any still-active bookings the customer holds.
        java.time.LocalDateTime now = java.time.LocalDateTime.now();
        for (com.aiwa.enums.BookingStatus st : java.util.List.of(
                com.aiwa.enums.BookingStatus.PENDING, com.aiwa.enums.BookingStatus.ACCEPTED)) {
            bookingRepo.findByCustomerIdAndStatus(user.getId(), st).forEach(b -> {
                b.setStatus(com.aiwa.enums.BookingStatus.CANCELLED);
                b.setCancelledBy("CUSTOMER");
                b.setCancellationReason("Account deleted");
                b.setCancelledAt(now);
                bookingRepo.save(b);
            });
        }

        // Anonymize personal data and disable the account (soft-delete + GDPR-style scrub).
        user.setFullName("Deleted user");
        user.setEmail(null);
        user.setPhone(null);
        user.setProfileImageUrl(null);
        user.setActive(false);
        userRepo.save(user);

        return ResponseEntity.ok(ApiResponse.Success.of("Account deleted", null));
    }

    private User resolveUser(UserDetails ud) {
        return userRepo.findByEmail(ud.getUsername())
                .or(() -> userRepo.findByPhone(ud.getUsername()))
                .orElseThrow();
    }

    private Long resolveUserId(UserDetails ud) {
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
}
