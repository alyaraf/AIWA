package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.repository.*;
import com.aiwa.service.SmsService;
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
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CR-21 follow-up: free text that arrives in a JSON body is no longer cut short by the URL length, so it reaches the
 * column it is stored in. A value longer than that column answers a translated 400, never a 500.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FreeTextBoundsApiTest {

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
    @Autowired ModerationCaseRepository moderationRepo;
    @Autowired ComplaintRepository complaintRepo;
    @Autowired TermsPolicyRepository termsRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @MockBean SmsService smsService;

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("bounds " + n).email("bounds" + n + "@freetext.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD))
                .role(role).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new HashSet<>()
                        : new HashSet<>(EnumSet.copyOf(java.util.List.of(perms))))
                .build());
    }

    private String bearer(User u) throws Exception {
        String body = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return "Bearer " + json.readTree(body).get("data").get("accessToken").asText();
    }

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    private String body(Map<String, String> fields) throws Exception {
        return json.writeValueAsString(fields);
    }

    private static String chars(int n) {
        return "x".repeat(n);
    }

    private static void tooLong(ResultActions r) throws Exception {
        r.andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("error.text_too_long"));
    }

    @Test
    void aChatReportReasonOverTheColumnAnswers400AndStoresNothing() throws Exception {
        User providerUser = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(providerUser).businessName("Bounds Studio " + providerUser.getId()).address("Zamalek, Cairo")
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
        String pAuth = bearer(providerUser), cAuth = bearer(user(UserRole.CUSTOMER));
        long booking = data(mvc.perform(post("/bookings").header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.getId(), "serviceId", s.getId(),
                                "bookingType", "SCHEDULED", "bookingDate", LocalDate.now().plusDays(3).toString(),
                                "startTime", "10:00", "homeService", false))))
                .andExpect(status().isCreated())).get("id").asLong();
        mvc.perform(patch("/bookings/{id}/accept", booking).header("Authorization", pAuth)).andExpect(status().isOk());
        long message = data(mvc.perform(post("/bookings/{id}/chat", booking).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("message", "Pay me outside the app"))))
                .andExpect(status().isCreated())).get("id").asLong();
        long before = moderationRepo.count();

        tooLong(mvc.perform(post("/bookings/{b}/chat/{m}/report", booking, message).header("Authorization", pAuth)
                .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", chars(1001))))));
        assertThat(moderationRepo.count()).isEqualTo(before);

        // The same text as the old URL parameter is bounded in the same place.
        tooLong(mvc.perform(post("/bookings/{b}/chat/{m}/report", booking, message).header("Authorization", pAuth)
                .param("reason", chars(1001))));

        // Exactly the column size still goes in.
        mvc.perform(post("/bookings/{b}/chat/{m}/report", booking, message).header("Authorization", pAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", chars(1000)))))
                .andExpect(status().isCreated());
        assertThat(moderationRepo.count()).isEqualTo(before + 1);
    }

    @Test
    void moderationNotesOverTheColumnAnswer400() throws Exception {
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        ModerationCase c = moderationRepo.save(ModerationCase.builder()
                .targetType(ModerationTargetType.CHAT_MESSAGE).targetId(1L).reason("Reported").build());

        tooLong(mvc.perform(patch("/admin/moderation/{id}/action", c.getId()).param("status", "DISMISSED")
                .header("Authorization", support).contentType(MediaType.APPLICATION_JSON)
                .content(body(Map.of("notes", chars(1001))))));
        assertThat(moderationRepo.findById(c.getId()).orElseThrow().getAdminNotes()).isNull();

        mvc.perform(patch("/admin/moderation/{id}/action", c.getId()).param("status", "DISMISSED")
                        .header("Authorization", support).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("notes", chars(1000)))))
                .andExpect(status().isOk());
    }

    @Test
    void complaintNotesAndFlagReasonsOverTheColumnAnswer400() throws Exception {
        User customer = user(UserRole.CUSTOMER);
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        long complaint = data(mvc.perform(post("/complaints").param("category", "OTHER")
                        .header("Authorization", bearer(customer)).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("description", "Rude behaviour")))).andExpect(status().isCreated()))
                .get("id").asLong();

        tooLong(mvc.perform(post("/admin/complaints/{id}/resolve", complaint).header("Authorization", support)
                .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("notes", chars(2001))))));
        assertThat(complaintRepo.findById(complaint).orElseThrow().getAdminNotes()).isNull();

        long flags = complaintRepo.count();
        tooLong(mvc.perform(post("/admin/users/{id}/flag", customer.getId()).header("Authorization", support)
                .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", chars(2001))))));
        assertThat(complaintRepo.count()).isEqualTo(flags);
    }

    @Test
    void policyTextAndLinkOverTheirColumnsAnswer400() throws Exception {
        String boss = bearer(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        tooLong(mvc.perform(post("/terms").header("Authorization", boss).contentType(MediaType.APPLICATION_JSON)
                .content(body(Map.of("version", "bounds-1", "type", "PRIVACY", "contentEn", chars(50001))))));
        tooLong(mvc.perform(post("/terms").header("Authorization", boss).contentType(MediaType.APPLICATION_JSON)
                .content(body(Map.of("version", "bounds-1", "type", "PRIVACY", "contentEn", "ok",
                        "contentAr", chars(50001))))));
        tooLong(mvc.perform(post("/terms").header("Authorization", boss).contentType(MediaType.APPLICATION_JSON)
                .content(body(Map.of("version", "bounds-1", "type", "PRIVACY", "contentEn", "ok",
                        "pdfUrl", "https://example.com/" + chars(520))))));
        assertThat(termsRepo.findByTypeAndVersion("PRIVACY", "bounds-1")).isEmpty();
    }
}
