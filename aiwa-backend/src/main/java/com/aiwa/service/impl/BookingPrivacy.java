package com.aiwa.service.impl;

import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;

/**
 * One place for the audience/state rules of what a booking reveals about the other party (audit B-02 / B-03).
 * <ul>
 *   <li>Customer contact (email/phone): only while the visit is live ({@link #contactVisible}).</li>
 *   <li>A home-based (INDIVIDUAL) provider's exact address and pin: only while the visit is live; before that
 *       (PENDING) and after it (rejected, expired, cancelled, completed, no-show) the public, rounded projection.</li>
 *   <li>Alternative-provider suggestions are discovery results and always use the public projection.</li>
 * </ul>
 */
public final class BookingPrivacy {

    private BookingPrivacy() {}

    public static boolean contactVisible(BookingStatus status) {
        return status != null && BookingServiceImpl.CONTACT_VISIBLE.contains(status);
    }

    /** The customer as the provider side may see them in this booking state. */
    static ApiResponse.UserDto customerFor(User u, BookingStatus status) {
        boolean contact = contactVisible(status);
        return ApiResponse.UserDto.builder().id(u.getId()).fullName(u.getFullName())
                .email(contact ? u.getEmail() : null)
                .phone(contact ? u.getPhone() : null)
                .profileImageUrl(u.getProfileImageUrl())
                .role(u.getRole()).gender(u.getGender()).active(u.isActive()).build();
    }

    /** Applies the location rule to a provider summary that belongs to a booking in {@code status}. */
    static ApiResponse.ProviderSummaryDto applyLocationPolicy(ApiResponse.ProviderSummaryDto summary, BookingStatus status) {
        if (!contactVisible(status)) {
            ProviderServiceImpl.hideHomeLocation(summary);
        }
        return summary;
    }

    /**
     * The visit destination as recorded on the booking (B-05). Falls back to the live saved address only for a row
     * that has no snapshot at all, so a later edit of the address cannot rewrite booking history.
     */
    public static ApiResponse.SavedAddressDto destinationOf(com.aiwa.entity.Booking b) {
        if (b.getDestinationAddress() != null) {
            return ApiResponse.SavedAddressDto.builder()
                    .id(b.getSavedAddress() != null ? b.getSavedAddress().getId() : null)
                    .label(b.getDestinationLabel())
                    .addressLine(b.getDestinationAddress())
                    .latitude(b.getDestinationLatitude())
                    .longitude(b.getDestinationLongitude())
                    .build();
        }
        com.aiwa.entity.SavedAddress a = b.getSavedAddress();
        return a == null ? null : ApiResponse.SavedAddressDto.builder()
                .id(a.getId()).label(a.getLabel()).addressLine(a.getAddressLine())
                .latitude(a.getLatitude()).longitude(a.getLongitude()).build();
    }
}
