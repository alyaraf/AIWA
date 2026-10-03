package com.aiwa.api;

import com.aiwa.entity.Availability;
import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.util.AiwaTime;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CR-11: a customer can check in only around the start of a venue booking
 * (aiwa.booking.check-in-lead-minutes before it, until the slot ends), and a
 * check-in never survives a move of the booking — so a provider can report a
 * no-show again instead of having to cancel (which costs a strike).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CheckInWindowApiTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired PasswordEncoder encoder;

    private String customer;
    private String provider;
    private long bookingId;

    private User user(UserRole role) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("checkin-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010771" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true).build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("data").get("accessToken").asText();
    }

    /** An accepted venue booking three days ahead at 10:00. */
    @BeforeEach
    void anAcceptedVenueBooking() throws Exception {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        com.aiwa.entity.Service s = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(p).name("Haircut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(p).dayOfWeek(d)
                    .startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(22, 0))
                    .slotDurationMinutes(30).available(true).build());
        }
        customer = login(user(UserRole.CUSTOMER));
        provider = login(owner);
        bookingId = json.readTree(mvc.perform(post("/bookings").header("Authorization", customer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "providerId", p.getId(), "serviceId", s.getId(), "bookingType", "SCHEDULED",
                                "bookingDate", AiwaTime.today().plusDays(3).toString(),
                                "startTime", "10:00", "homeService", false))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
        mvc.perform(patch("/bookings/" + bookingId + "/accept").header("Authorization", provider))
                .andExpect(status().isOk());
    }

    private Booking booking() {
        return bookingRepo.findById(bookingId).orElseThrow();
    }

    /** Puts the (60-minute) booking at another start, as if time had passed. */
    private void startsAt(LocalDateTime start) {
        Booking b = booking();
        b.setBookingDate(start.toLocalDate());
        b.setStartTime(start.toLocalTime());
        b.setEndTime(start.toLocalTime().plusMinutes(60));
        bookingRepo.save(b);
    }

    private static LocalDateTime minutesFromNow(long minutes) {
        return AiwaTime.now().plusMinutes(minutes).withSecond(0).withNano(0);
    }

    @Test
    void checkInDaysBeforeTheBookingIsRefused() throws Exception {
        startsAt(LocalDateTime.of(AiwaTime.today().plusDays(2), LocalTime.of(10, 0)));

        mvc.perform(patch("/bookings/" + bookingId + "/check-in").header("Authorization", customer))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.checkin_too_early"));
        assertThat(booking().getCheckedInAt()).isNull();
    }

    @Test
    void checkInShortlyBeforeTheStartWorks() throws Exception {
        startsAt(minutesFromNow(20));

        mvc.perform(patch("/bookings/" + bookingId + "/check-in").header("Authorization", customer))
                .andExpect(status().isOk());
        assertThat(booking().getCheckedInAt()).isNotNull();
    }

    @Test
    void checkInAfterTheSlotEndedIsRefused() throws Exception {
        startsAt(minutesFromNow(-180));

        mvc.perform(patch("/bookings/" + bookingId + "/check-in").header("Authorization", customer))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.checkin_too_late"));
        assertThat(booking().getCheckedInAt()).isNull();
    }

    @Test
    void aRescheduleClearsTheCheckInSoANoShowIsPossibleAgain() throws Exception {
        // A check-in made days early (possible before the window existed).
        Booking b = booking();
        b.setCheckedInAt(LocalDateTime.now());
        bookingRepo.save(b);

        LocalDate newDate = AiwaTime.today().plusDays(4);
        mvc.perform(patch("/bookings/" + bookingId + "/reschedule").header("Authorization", customer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingDate", newDate.toString(), "startTime", "11:00"))))
                .andExpect(status().isOk());
        assertThat(booking().getCheckedInAt()).isNull();

        // The provider confirms the new time, the customer never comes.
        mvc.perform(patch("/bookings/" + bookingId + "/accept").header("Authorization", provider))
                .andExpect(status().isOk());
        startsAt(minutesFromNow(-120));
        mvc.perform(patch("/bookings/" + bookingId + "/no-show").header("Authorization", provider))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("NO_SHOW"));
    }

    @Test
    void anAcceptedProposalClearsTheCheckIn() throws Exception {
        // What the old reschedule left behind: a pending request that is still checked in.
        Booking b = booking();
        b.setStatus(BookingStatus.PENDING);
        b.setCheckedInAt(LocalDateTime.now());
        bookingRepo.save(b);

        mvc.perform(patch("/bookings/" + bookingId + "/propose-time").header("Authorization", provider)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "bookingDate", AiwaTime.today().plusDays(4).toString(), "startTime", "12:00"))))
                .andExpect(status().isOk());
        mvc.perform(patch("/bookings/" + bookingId + "/proposal-response").param("accept", "true")
                        .header("Authorization", customer))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("ACCEPTED"));
        assertThat(booking().getCheckedInAt()).isNull();
    }
}
