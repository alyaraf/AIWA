package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.Availability;
import com.aiwa.entity.Notification;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
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
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Hardening round 2026-10-04: input bounds (L-9), approval needs documents (L-12), the last
 * super admin can't be deleted (L-5), one open report per chat message (L-26), notification
 * retention (M-8) and the shorter admin refresh token (L-18).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HardeningApiTest {

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
    @Autowired JdbcTemplate jdbc;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void resetLimits() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("hard-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone(TestPhones.next())
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

    private ProviderProfile provider(VerificationStatus status, boolean withDocuments) {
        User owner = user(UserRole.PROVIDER);
        ProviderProfile p = ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(status).travelBufferMinutes(0).build();
        if (withDocuments) {
            p.setNationalIdFrontPath("uploads/private/id/front.jpg");
            p.setNationalIdBackPath("uploads/private/id/back.jpg");
            p.setSelfiePath("uploads/private/id/selfie.jpg");
        }
        return providerRepo.save(p);
    }

    // ── L-12 ───────────────────────────────────────────────────────────────────

    @Test
    void aProviderCannotBeApprovedUntilAllThreeDocumentsWereSubmitted() throws Exception {
        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        ProviderProfile bare = provider(VerificationStatus.PENDING_VERIFICATION, false);
        mvc.perform(post("/admin/verification/" + bare.getId() + "/approve").header("Authorization", support))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("verification.error.documents_missing"));
        assertThat(providerRepo.findById(bare.getId()).orElseThrow().getVerificationStatus())
                .isEqualTo(VerificationStatus.PENDING_VERIFICATION);

        ProviderProfile full = provider(VerificationStatus.PENDING_VERIFICATION, true);
        mvc.perform(post("/admin/verification/" + full.getId() + "/approve").header("Authorization", support))
                .andExpect(status().isOk());
        assertThat(providerRepo.findById(full.getId()).orElseThrow().getVerificationStatus())
                .isEqualTo(VerificationStatus.APPROVED);
    }

    // ── L-9 ────────────────────────────────────────────────────────────────────

    @Test
    void anAdminPasswordLongerThanBcryptReadsIsRefused() throws Exception {
        String boss = login(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        mvc.perform(post("/admin/users/admins").header("Authorization", boss)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("fullName", "New Admin", "email", "newadmin@test.aiwa",
                                "password", "x".repeat(73), "permissions", List.of("SUPPORT")))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void impossibleCoordinatesAndSlotLengthsAreRefused() throws Exception {
        ProviderProfile p = provider(VerificationStatus.APPROVED, true);
        String providerToken = login(p.getUser());
        mvc.perform(post("/provider/availability").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dayOfWeek\":\"MONDAY\",\"startTime\":\"09:00\",\"endTime\":\"17:00\",\"slotDurationMinutes\":1}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/provider/availability").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dayOfWeek\":\"MONDAY\",\"startTime\":\"09:00\",\"endTime\":\"17:00\",\"slotDurationMinutes\":60}"))
                .andExpect(status().is2xxSuccessful());
        // an SOS with a latitude of 200 is a 400, not a stored nonsense position
        mvc.perform(post("/bookings/1/safety").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"type\":\"SOS\",\"latitude\":200,\"longitude\":31}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void verificationTextsLongerThanTheirColumnsAreRefused() throws Exception {
        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        ProviderProfile p = provider(VerificationStatus.PENDING_VERIFICATION, true);
        mvc.perform(post("/admin/verification/" + p.getId() + "/reject").header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("reason", "r".repeat(256)))))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("error.text_too_long"));
    }

    // ── L-26 ───────────────────────────────────────────────────────────────────

    @Test
    void reportingTheSameChatMessageAgainDoesNotOpenAnotherCase() throws Exception {
        ProviderProfile p = provider(VerificationStatus.APPROVED, true);
        com.aiwa.entity.Service svc = serviceRepo.save(com.aiwa.entity.Service.builder().provider(p).name("Cut")
                .category(ServiceCategory.HAIR).price(new BigDecimal("100")).durationMinutes(30).active(true).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(p).dayOfWeek(d).startTime(LocalTime.of(8, 0))
                    .endTime(LocalTime.of(22, 0)).slotDurationMinutes(30).available(true).build());
        }
        User customer = user(UserRole.CUSTOMER);
        String customerToken = login(customer);
        String providerToken = login(p.getUser());
        long booking = json.readTree(mvc.perform(post("/bookings").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.getId(), "serviceId", svc.getId(),
                                "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(3).toString(),
                                "startTime", "10:00", "homeService", false))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
        long message = json.readTree(mvc.perform(post("/bookings/" + booking + "/chat").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"message\":\"rude text\"}"))
                .andExpect(status().is2xxSuccessful()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();

        for (int i = 0; i < 3; i++) {
            mvc.perform(post("/bookings/" + booking + "/chat/" + message + "/report").header("Authorization", providerToken)
                    .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"abuse\"}")).andExpect(status().isCreated());
        }
        Integer open = jdbc.queryForObject("SELECT count(*) FROM moderation_cases WHERE target_id = ? AND target_type = 'CHAT_MESSAGE'",
                Integer.class, message);
        assertThat(open).isEqualTo(1);
    }

    // ── M-8 ────────────────────────────────────────────────────────────────────

    @Test
    void theRetentionDeleteRemovesOnlyOldNotifications() {
        User u = user(UserRole.CUSTOMER);
        Notification oldOne = notificationRepo.save(Notification.builder().user(u).type(NotificationType.CHAT_MESSAGE)
                .titleEn("old").titleAr("old").bodyEn("old").bodyAr("old").build());
        Notification fresh = notificationRepo.save(Notification.builder().user(u).type(NotificationType.CHAT_MESSAGE)
                .titleEn("new").titleAr("new").bodyEn("new").bodyAr("new").build());
        jdbc.update("UPDATE notifications SET created_at = ? WHERE id = ?", LocalDateTime.now().minusDays(200), oldOne.getId());

        int removed = notificationRepo.deleteOlderThan(LocalDateTime.now().minusDays(180));

        assertThat(removed).isGreaterThanOrEqualTo(1);
        assertThat(notificationRepo.findById(oldOne.getId())).isEmpty();
        assertThat(notificationRepo.findById(fresh.getId())).isPresent();
    }

    // ── L-18 ───────────────────────────────────────────────────────────────────

    @Test
    void anAdminRefreshTokenLivesHoursNotDays() throws Exception {
        User admin = user(UserRole.ADMIN, AdminPermission.SUPPORT);
        User customer = user(UserRole.CUSTOMER);
        long adminLife = refreshLifetimeMillis(admin);
        long customerLife = refreshLifetimeMillis(customer);
        assertThat(adminLife).isLessThanOrEqualTo(9L * 3600_000L);
        assertThat(customerLife).isGreaterThan(6L * 24 * 3600_000L);
    }

    private long refreshLifetimeMillis(User u) throws Exception {
        var res = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse();
        var body = json.readTree(res.getContentAsString()).get("data");
        // F-05: an admin refresh token is in the HttpOnly cookie, not in the body.
        String refresh = body.hasNonNull("refreshToken") ? body.get("refreshToken").asText()
                : res.getCookie("aiwa_admin_refresh").getValue();
        String payload = new String(java.util.Base64.getUrlDecoder().decode(refresh.split("\\.")[1]));
        var claims = json.readTree(payload);
        return (claims.get("exp").asLong() - claims.get("iat").asLong()) * 1000L;
    }
}
