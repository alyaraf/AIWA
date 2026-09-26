package com.aiwa.controller;

import com.aiwa.entity.Booking;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.SavedAddressRepository;
import com.aiwa.repository.UserRepository;
import org.junit.jupiter.api.Test;
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

    private final AccountController controller = new AccountController(userRepo, addressRepo, bookingRepo);

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")));
    }

    @Test
    void deleteAnonymizesUserAndCancelsActiveBookings() {
        User u = User.builder().id(9L).fullName("Real Name").email("me@x.com").phone("+2010")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByEmail("me@x.com")).thenReturn(Optional.of(u));

        Booking pending = Booking.builder().id(1L).status(BookingStatus.PENDING).build();
        Booking accepted = Booking.builder().id(2L).status(BookingStatus.ACCEPTED).build();
        when(bookingRepo.findByCustomerIdAndStatus(9L, BookingStatus.PENDING)).thenReturn(List.of(pending));
        when(bookingRepo.findByCustomerIdAndStatus(9L, BookingStatus.ACCEPTED)).thenReturn(List.of(accepted));

        controller.deleteAccount(principal("me@x.com"));

        // anonymized + disabled
        assertThat(u.isActive()).isFalse();
        assertThat(u.getEmail()).isNull();
        assertThat(u.getPhone()).isNull();
        assertThat(u.getFullName()).isEqualTo("Deleted user");
        verify(userRepo).save(u);

        // active bookings cancelled
        assertThat(pending.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(accepted.getStatus()).isEqualTo(BookingStatus.CANCELLED);
        verify(bookingRepo, times(2)).save(any(Booking.class));
    }
}
