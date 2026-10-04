package com.aiwa.api;

import com.aiwa.entity.Availability;
import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.NotificationType;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.NotificationRepository;
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
import org.springframework.data.domain.PageRequest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * H-1 (audit 2026-10-03): a suspended or deactivated provider used to keep their
 * accepted bookings and could still set off for a customer's home. Now their
 * bookings that haven't started are cancelled (customers told), a session in
 * progress can still be finished, and every other forward step is refused.
 * Also M-9: role 403s and 401s carry the standard error body with a code.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProviderSuspensionApiTest {

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
    @Autowired NotificationRepository notificationRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    private User owner;
    private ProviderProfile profile;
    private com.aiwa.entity.Service service;
    private User customer;
    private String customerToken;
    private String providerToken;

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("suspend-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010772" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new HashSet<>() : new HashSet<>(EnumSet.copyOf(List.of(perms))))
                .build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("data").get("accessToken").asText();
    }

    @BeforeEach
    void anApprovedProvider() throws Exception {
        ((InMemoryRedisRuntimeService) redis).clear(); // per-IP sign-in limit
        owner = user(UserRole.PROVIDER);
        profile = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        service = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(profile).name("Haircut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(profile).dayOfWeek(d)
                    .startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(22, 0))
                    .slotDurationMinutes(30).available(true).build());
        }
        customer = user(UserRole.CUSTOMER);
        customerToken = login(customer);
        providerToken = login(owner);
    }

    private long book(int daysAhead, String time) throws Exception {
        return json.readTree(mvc.perform(post("/bookings").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "providerId", profile.getId(), "serviceId", service.getId(), "bookingType", "SCHEDULED",
                                "bookingDate", AiwaTime.today().plusDays(daysAhead).toString(),
                                "startTime", time, "homeService", false))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
    }

    private Booking booking(long id) {
        return bookingRepo.findById(id).orElseThrow();
    }

    private void setStatus(long id, BookingStatus s) {
        Booking b = booking(id);
        b.setStatus(s);
        bookingRepo.save(b);
    }

    private long cancellationNotices() {
        return notificationRepo.findByUserIdOrderByCreatedAtDesc(customer.getId(), PageRequest.of(0, 50))
                .stream().filter(n -> n.getType() == NotificationType.BOOKING_CANCELLED).count();
    }

    @Test
    void suspendingCancelsUpcomingBookingsTellsTheCustomerAndLeavesASessionInProgress() throws Exception {
        long pending = book(3, "10:00");
        long accepted = book(4, "10:00");
        mvc.perform(patch("/bookings/" + accepted + "/accept").header("Authorization", providerToken))
                .andExpect(status().isOk());
        long inProgress = book(5, "10:00");
        setStatus(inProgress, BookingStatus.IN_PROGRESS);

        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        mvc.perform(post("/admin/verification/" + profile.getId() + "/suspend").header("Authorization", support))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Provider suspended; 2 upcoming booking(s) cancelled"));

        assertThat(booking(pending).getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(booking(accepted).getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(booking(accepted).getCancelledBy()).isEqualTo("ADMIN");
        assertThat(booking(inProgress).getStatus()).isEqualTo(BookingStatus.IN_PROGRESS);
        assertThat(cancellationNotices()).isEqualTo(2);
    }

    @Test
    void aSuspendedProviderCannotTakeABookingForwardButCanDeclineIt() throws Exception {
        long first = book(3, "10:00");
        long second = book(3, "12:00");
        profile.setVerificationStatus(VerificationStatus.SUSPENDED);
        providerRepo.save(profile);

        mvc.perform(patch("/bookings/" + first + "/accept").header("Authorization", providerToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("booking.error.provider_suspended"));
        assertThat(booking(first).getStatus()).isEqualTo(BookingStatus.PENDING);

        mvc.perform(patch("/bookings/" + second + "/reject").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Fully booked\"}"))
                .andExpect(status().isOk());
        assertThat(booking(second).getStatus()).isEqualTo(BookingStatus.REJECTED);
    }

    @Test
    void deactivatingAProviderAccountCancelsTheirUpcomingBookings() throws Exception {
        long accepted = book(3, "10:00");
        mvc.perform(patch("/bookings/" + accepted + "/accept").header("Authorization", providerToken))
                .andExpect(status().isOk());

        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        mvc.perform(patch("/admin/users/" + owner.getId() + "/deactivate").header("Authorization", support))
                .andExpect(status().isOk());

        assertThat(booking(accepted).getStatus()).isEqualTo(BookingStatus.CANCELLED);
        assertThat(cancellationNotices()).isEqualTo(1);
    }

    @Test
    void anInvalidTransitionAnswersWithAKeyNotAnEnglishSentence() throws Exception {
        long id = book(3, "10:00");
        mvc.perform(patch("/bookings/" + id + "/arrived").header("Authorization", providerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.invalid_transition"));
    }

    @Test
    void aRoleDenialCarriesTheRoleCodeAndA401HasTheStandardBody() throws Exception {
        mvc.perform(get("/admin/users").header("Authorization", customerToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.code").value("auth.error.forbidden_role"));
        mvc.perform(get("/notifications"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.code").value("auth.error.authentication_required"));
    }
}
