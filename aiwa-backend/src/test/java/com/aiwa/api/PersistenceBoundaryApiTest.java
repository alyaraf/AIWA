package com.aiwa.api;

import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ReviewRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.JsonNode;
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
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * B-06 / B-07: real persistence, real HTTP, production open-in-view semantics (off). Mocked repositories
 * cannot show a lazy collection escaping its transaction or a delete without one.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PersistenceBoundaryApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired ReviewRepository reviewRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @Autowired org.springframework.core.env.Environment env;

    @BeforeEach
    void reset() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role, Set<AdminPermission> perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("pb-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010551" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms)).build());
    }

    private String login(User u) throws Exception {
        JsonNode d = json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
        return "Bearer " + d.get("accessToken").asText();
    }

    @Test
    void theTestProfileRunsWithOpenInViewOff() {
        assertThat(env.getProperty("spring.jpa.open-in-view")).isEqualTo("false");
    }

    @Test
    void adminReviewListSerializesPersistedQuickTagsWithoutOpenInView() throws Exception {
        User owner = user(UserRole.PROVIDER, Set.of());
        User customer = user(UserRole.CUSTOMER, Set.of());
        ProviderProfile profile = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Tagged")
                .address("x").primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).build());
        com.aiwa.entity.Service svc = serviceRepo.save(com.aiwa.entity.Service.builder().provider(profile).name("Cut")
                .category(ServiceCategory.HAIR).price(new BigDecimal("100")).durationMinutes(30).active(true).build());
        Booking booking = bookingRepo.save(Booking.builder().customer(customer).provider(profile).service(svc)
                .bookingDate(LocalDate.now()).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .status(BookingStatus.COMPLETED).totalPrice(new BigDecimal("100"))
                .paymentStatus(PaymentStatus.CASH_CONFIRMED).build());
        reviewRepo.save(Review.builder().user(customer).provider(profile).booking(booking).rating(4)
                .comment("fine").hidden(true).quickTags(new java.util.ArrayList<>(List.of("Punctual", "Skilled"))).build());

        String support = login(user(UserRole.ADMIN, Set.of(AdminPermission.SUPPORT)));
        JsonNode page = json.readTree(mvc.perform(get("/admin/reviews").header("Authorization", support))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");

        JsonNode row = page.get("content").get(0);
        assertThat(row.get("quickTags")).extracting(JsonNode::asText).containsExactlyInAnyOrder("Punctual", "Skilled");
        assertThat(row.get("hidden").asBoolean()).isTrue();
    }

    @Test
    void unsavingAProviderDeletesTheRowAndIsIdempotent() throws Exception {
        User owner = user(UserRole.PROVIDER, Set.of());
        ProviderProfile profile = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Heart")
                .address("x").primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).build());
        String customer = login(user(UserRole.CUSTOMER, Set.of()));

        mvc.perform(post("/users/me/saved/" + profile.getId()).header("Authorization", customer))
                .andExpect(status().isCreated());
        mvc.perform(get("/users/me/saved/" + profile.getId() + "/check").header("Authorization", customer))
                .andExpect(status().isOk());

        mvc.perform(delete("/users/me/saved/" + profile.getId()).header("Authorization", customer))
                .andExpect(status().isOk());
        mvc.perform(delete("/users/me/saved/" + profile.getId()).header("Authorization", customer)) // duplicate delete
                .andExpect(status().isOk());

        JsonNode checked = json.readTree(mvc.perform(get("/users/me/saved/" + profile.getId() + "/check")
                .header("Authorization", customer)).andReturn().getResponse().getContentAsString());
        assertThat(checked.get("data").asBoolean()).isFalse();
    }

    /** M-06: the buffer has its own narrow endpoint, so changing it can never put back an older business profile. */
    @Test
    void theTravelBufferIsUpdatedWithoutTouchingTheBusinessProfile() throws Exception {
        User owner = user(UserRole.PROVIDER, Set.of());
        ProviderProfile profile = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Newer Name")
                .bio("newer bio").address("newer address").primaryCategory(ServiceCategory.HAIR)
                .travelBufferMinutes(10).verificationStatus(VerificationStatus.APPROVED).build());
        String token = login(owner);

        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .patch("/provider/mode/travel-buffer").param("minutes", "45").header("Authorization", token))
                .andExpect(status().isOk());
        ProviderProfile after = providerRepo.findById(profile.getId()).orElseThrow();
        assertThat(after.getTravelBufferMinutes()).isEqualTo(45);
        assertThat(after.getBusinessName()).isEqualTo("Newer Name");
        assertThat(after.getBio()).isEqualTo("newer bio");
        assertThat(after.getAddress()).isEqualTo("newer address");

        for (String bad : new String[]{"-1", "61", "1000"}) {
            mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                            .patch("/provider/mode/travel-buffer").param("minutes", bad).header("Authorization", token))
                    .andExpect(status().isBadRequest());
        }
        assertThat(providerRepo.findById(profile.getId()).orElseThrow().getTravelBufferMinutes()).isEqualTo(45);

        // a customer cannot use the provider endpoint
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .patch("/provider/mode/travel-buffer").param("minutes", "5")
                        .header("Authorization", login(user(UserRole.CUSTOMER, Set.of()))))
                .andExpect(status().isForbidden());
    }
}
