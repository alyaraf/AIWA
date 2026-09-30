package com.aiwa.controller;

import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Service;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.*;
import com.aiwa.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AccountDeletionTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final SavedAddressRepository addressRepo = mock(SavedAddressRepository.class);
    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final TrustedContactRepository trustedContactRepo = mock(TrustedContactRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final com.aiwa.service.impl.FileStorageServiceImpl fileStorage = mock(com.aiwa.service.impl.FileStorageServiceImpl.class);
    private final GalleryImageRepository galleryRepo = mock(GalleryImageRepository.class);

    private final com.aiwa.service.impl.AccountDeletionService controller = new com.aiwa.service.impl.AccountDeletionService(
            userRepo, addressRepo, bookingRepo, trustedContactRepo, providerRepo, notificationService,
            fileStorage, galleryRepo);

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    private static Booking booking(long id, BookingStatus status, ProviderProfile provider, User customer) {
        return Booking.builder().id(id).status(status).provider(provider).customer(customer)
                .service(Service.builder().id(3L).name("Haircut").build()).build();
    }

    @Test
    void deleteAnonymizesUserCancelsActiveBookingsAndTellsTheProvider() {
        User u = User.builder().id(9L).fullName("Real Name").email("me@x.com").phone("+2010")
                .role(UserRole.CUSTOMER).active(true).pushToken("tok").build();
        when(userRepo.findByEmail("me@x.com")).thenReturn(Optional.of(u));
        User providerUser = User.builder().id(20L).build();
        ProviderProfile provider = ProviderProfile.builder().id(7L).user(providerUser).build();

        Booking pending = booking(1L, BookingStatus.PENDING, provider, u);
        Booking accepted = booking(2L, BookingStatus.ACCEPTED, provider, u);
        when(bookingRepo.findByCustomerIdAndStatus(9L, BookingStatus.PENDING)).thenReturn(List.of(pending));
        when(bookingRepo.findByCustomerIdAndStatus(9L, BookingStatus.ACCEPTED)).thenReturn(List.of(accepted));
        when(providerRepo.findByUserId(9L)).thenReturn(Optional.empty());

        controller.delete(u);

        // anonymized + disabled + every session revoked
        assertThat(u.isActive()).isFalse();
        assertThat(u.getEmail()).isNull();
        assertThat(u.getPhone()).isNull();
        assertThat(u.getPushToken()).isNull();
        assertThat(u.getFullName()).isEqualTo("Deleted user");
        assertThat(u.getTokensValidAfter()).isNotNull();
        verify(userRepo).save(u);

        // active bookings cancelled, and the provider hears about each one
        assertThat(pending.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(accepted.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        verify(bookingRepo, times(2)).save(any(Booking.class));
        verify(notificationService, times(2)).send(eq(20L), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void deletingAProviderAccountTakesTheListingDownAndCancelsItsBookings() {
        User u = User.builder().id(9L).fullName("Studio Owner").email("pro@x.com")
                .role(UserRole.PROVIDER).active(true).build();
        when(userRepo.findByEmail("pro@x.com")).thenReturn(Optional.of(u));
        ProviderProfile profile = ProviderProfile.builder().id(7L).user(u)
                .verificationStatus(VerificationStatus.APPROVED).build();
        when(providerRepo.findByUserId(9L)).thenReturn(Optional.of(profile));
        User customer = User.builder().id(30L).build();
        Booking upcoming = booking(5L, BookingStatus.ACCEPTED, profile, customer);
        when(bookingRepo.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc(eq(7L), anyCollection(), any()))
                .thenReturn(new PageImpl<>(List.of(upcoming)));

        controller.delete(u);

        assertThat(profile.getVerificationStatus()).isEqualTo(VerificationStatus.SUSPENDED);
        assertThat(profile.isOfflineMode()).isTrue();
        assertThat(upcoming.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        verify(notificationService).send(eq(30L), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void deletionErasesAddressesIdDocumentsGalleryAndAvatar() {
        User u = User.builder().id(9L).fullName("Studio Owner").email("pro@x.com").role(UserRole.PROVIDER)
                .active(true).profileImageUrl("/files/public/avatars/a.jpg").build();
        when(userRepo.findByEmail("pro@x.com")).thenReturn(Optional.of(u));
        ProviderProfile profile = ProviderProfile.builder().id(7L).user(u)
                .nationalIdFrontPath("ids/front.jpg").nationalIdBackPath("ids/back.jpg").selfiePath("ids/selfie.jpg").build();
        when(providerRepo.findByUserId(9L)).thenReturn(Optional.of(profile));
        when(bookingRepo.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc(eq(7L), anyCollection(), any()))
                .thenReturn(new PageImpl<>(List.of()));
        com.aiwa.entity.GalleryImage photo = com.aiwa.entity.GalleryImage.builder().id(4L).provider(profile)
                .url("/files/public/gallery/g.jpg").build();
        when(galleryRepo.findByProviderIdOrderByIdAsc(7L)).thenReturn(List.of(photo));
        com.aiwa.entity.SavedAddress home = com.aiwa.entity.SavedAddress.builder().id(3L).user(u).label("Home")
                .addressLine("12 Nile St, Zamalek").latitude(30.06).longitude(31.22).defaultAddress(true).build();
        when(addressRepo.findByUserId(9L)).thenReturn(List.of(home));

        controller.delete(u);

        // OPS-4: what the privacy policy promises to erase is erased.
        assertThat(home.getAddressLine()).isEqualTo("Deleted");
        assertThat(home.getLatitude()).isNull();
        assertThat(home.getLongitude()).isNull();
        assertThat(home.isArchived()).isTrue();
        assertThat(profile.getNationalIdFrontPath()).isNull();
        assertThat(profile.getSelfiePath()).isNull();
        assertThat(u.getProfileImageUrl()).isNull();
        verify(galleryRepo).deleteAll(List.of(photo));
        // No transaction in a plain unit test, so the files go straight away.
        verify(fileStorage).deletePrivate("ids/front.jpg");
        verify(fileStorage).deletePrivate("ids/back.jpg");
        verify(fileStorage).deletePrivate("ids/selfie.jpg");
        verify(fileStorage).deletePublic("/files/public/gallery/g.jpg");
        verify(fileStorage).deletePublic("/files/public/avatars/a.jpg");
    }
}
