package com.aiwa.api;

import com.aiwa.entity.Availability;
import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.*;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.*;
import com.aiwa.service.impl.BookingServiceImpl;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.util.AiwaTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * CR-03: the customer's "not paid" is only accepted for a set time after the
 * provider completed the booking (aiwa.booking.payment-dispute-window-hours).
 * The window is set to 0 here, so it has already closed when the customer answers.
 */
@SpringBootTest(properties = "aiwa.booking.payment-dispute-window-hours=0")
@ActiveProfiles("test")
class PaymentDisputeWindowTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired CommissionLedgerRepository ledgerRepo;
    @Autowired BookingServiceImpl bookingService;

    private User user(UserRole role, String tag, String phone) {
        return userRepo.save(User.builder().fullName(tag).email(tag + "@window.aiwa").phone(phone)
                .password("x").role(role).active(true).termsAccepted(true).build());
    }

    @Test
    void notPaidAfterTheWindowIsRefused() {
        User owner = user(UserRole.PROVIDER, "window-provider", "+201099900001");
        User customer = user(UserRole.CUSTOMER, "window-customer", "+201099900002");
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Window Studio").address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        com.aiwa.entity.Service s = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(p).name("Haircut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        LocalDateTime soon = AiwaTime.now().plusMinutes(30).withSecond(0).withNano(0);
        long id = bookingRepo.save(Booking.builder().customer(customer).provider(p).service(s)
                .bookingDate(soon.toLocalDate()).startTime(soon.toLocalTime()).endTime(soon.toLocalTime().plusMinutes(60))
                .status(BookingStatus.IN_PROGRESS).totalPrice(new BigDecimal("300"))
                .paymentStatus(PaymentStatus.CASH_PENDING).build()).getId();

        bookingService.complete(owner.getId(), id, true);

        assertThatThrownBy(() -> bookingService.confirmPayment(customer.getId(), id, false))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("booking.error.payment_dispute_window_closed");
        assertThat(bookingRepo.findById(id).orElseThrow().getPaymentStatus()).isEqualTo(PaymentStatus.CASH_CONFIRMED);
        assertThat(ledgerRepo.findByBookingId(id).orElseThrow().getStatus()).isEqualTo(LedgerEntryStatus.DUE);
    }
}
