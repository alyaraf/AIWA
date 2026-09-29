package com.aiwa.api;

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
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.EnumSet;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * API-level tests (BE-23): real HTTP stack — security filter chain, JWT filter,
 * controllers, validation, exception mapping and JPA on H2 — with Redis replaced
 * by an in-memory map and SMS captured. Covers sign-up, token types, session
 * revocation, the booking lifecycle across both roles, access denial between
 * users, the SOS flow, and the file endpoints.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ApiFlowIntegrationTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(100);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired TrustedContactRepository trustedContactRepo;
    @Autowired NotificationRepository notificationRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @MockBean SmsService smsService;

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    // ── fixtures ─────────────────────────────────────────────────────────────

    private static String uniquePhone() {
        return "+2010" + String.format("%08d", SEQ.incrementAndGet());
    }

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder()
                .fullName(role.name().toLowerCase() + " " + n)
                .email(role.name().toLowerCase() + n + "@test.aiwa")
                .phone(uniquePhone())
                .password(encoder.encode(PASSWORD))
                .role(role).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new java.util.HashSet<>()
                        : new java.util.HashSet<>(EnumSet.copyOf(java.util.List.of(perms))))
                .build());
    }

    private record Provider(User user, ProviderProfile profile, com.aiwa.entity.Service service) {}

    private Provider approvedProvider() {
        User u = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(u).businessName("Studio " + u.getId()).address("Zamalek, Cairo")
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
        return new Provider(u, p, s);
    }

    private String login(User u) throws Exception {
        return tokens(u.getEmail()).get("accessToken").asText();
    }

    private JsonNode tokens(String identifier) throws Exception {
        MvcResult r = mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", identifier, "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn();
        return json.readTree(r.getResponse().getContentAsString()).get("data");
    }

    private static String bearer(String token) {
        return "Bearer " + token;
    }

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    private long book(String customerToken, Provider p, LocalDate date, LocalTime time) throws Exception {
        return data(mvc.perform(post("/bookings").header("Authorization", bearer(customerToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "providerId", p.profile().getId(), "serviceId", p.service().getId(),
                                "bookingType", "SCHEDULED", "bookingDate", date.toString(),
                                "startTime", time.toString(), "homeService", false))))
                .andExpect(status().isCreated())).get("id").asLong();
    }

    // ── sign-up & tokens ─────────────────────────────────────────────────────

    @Test
    void phoneSignUpRequiresTheOtpAndThenWorks() throws Exception {
        String phone = uniquePhone();
        Map<String, Object> register = Map.of("fullName", "New Customer", "phone", phone,
                "password", PASSWORD, "role", "CUSTOMER");

        // Without a verified phone the registration is refused.
        mvc.perform(post("/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(register)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.phone_not_verified"));

        mvc.perform(post("/auth/send-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", phone))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(smsService).sendOtp(eq(phone), code.capture(), anyInt());

        mvc.perform(post("/auth/verify-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", phone, "code", code.getValue()))))
                .andExpect(status().isOk());

        String access = data(mvc.perform(post("/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(register)))
                .andExpect(status().isCreated())).get("accessToken").asText();

        mvc.perform(get("/auth/me").header("Authorization", bearer(access)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(phone));
    }

    @Test
    void otpSendsArePerPhoneLimited() throws Exception {
        String phone = uniquePhone();
        for (int i = 0; i < 3; i++) {
            mvc.perform(post("/auth/send-otp").contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(Map.of("phone", phone))))
                    .andExpect(status().isOk());
        }
        mvc.perform(post("/auth/send-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", phone))))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("otp.error.too_many_sends"));
    }

    @Test
    void aRefreshTokenIsNotAnAccessTokenAndRotates() throws Exception {
        User u = user(UserRole.CUSTOMER);
        JsonNode t = tokens(u.getEmail());
        String refresh = t.get("refreshToken").asText();

        mvc.perform(get("/auth/me").header("Authorization", bearer(refresh)))
                .andExpect(status().isUnauthorized());

        mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", refresh))))
                .andExpect(status().isOk());
        // Rotation: the same refresh token can't be used twice.
        mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", refresh))))
                .andExpect(status().isUnauthorized());
        // And an access token can't be used as a refresh token.
        mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", t.get("accessToken").asText()))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void theMfaChallengeTokenCannotCallTheApi() throws Exception {
        User admin = user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN);
        admin.setTotpEnabled(true);
        admin.setTotpSecret("JBSWY3DPEHPK3PXP");
        userRepo.save(admin);

        JsonNode t = tokens(admin.getEmail());
        assertThat(t.get("mfaRequired").asBoolean()).isTrue();
        String mfaToken = t.get("mfaToken").asText();

        // Before the fix this returned 200 — the password alone opened the admin API.
        mvc.perform(get("/admin/dashboard").header("Authorization", bearer(mfaToken)))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/auth/me").header("Authorization", bearer(mfaToken)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void aPasswordResetSignsOutExistingSessions() throws Exception {
        User u = user(UserRole.CUSTOMER);
        String oldAccess = login(u);
        mvc.perform(get("/auth/me").header("Authorization", bearer(oldAccess))).andExpect(status().isOk());
        Thread.sleep(1100); // JWT iat has second precision

        mvc.perform(post("/auth/send-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", u.getPhone()))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(smsService, atLeastOnce()).sendOtp(eq(u.getPhone()), code.capture(), anyInt());
        mvc.perform(post("/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", u.getPhone(),
                                "code", code.getValue(), "newPassword", "Another456!"))))
                .andExpect(status().isOk());

        mvc.perform(get("/auth/me").header("Authorization", bearer(oldAccess)))
                .andExpect(status().isUnauthorized());
    }

    // ── booking lifecycle across both roles ──────────────────────────────────

    @Test
    void bookingLifecycleWithConflictContactAndReviews() throws Exception {
        Provider p = approvedProvider();
        User customer = user(UserRole.CUSTOMER);
        User other = user(UserRole.CUSTOMER);
        String cTok = login(customer), oTok = login(other), pTok = login(p.user());
        LocalDate day = LocalDate.now().plusDays(2);

        long id = book(cTok, p, day, LocalTime.of(10, 0));

        // Same slot for someone else → 409 with a stable code (BE-14).
        mvc.perform(post("/bookings").header("Authorization", bearer(oTok)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.profile().getId(),
                                "serviceId", p.service().getId(), "bookingType", "SCHEDULED",
                                "bookingDate", day.toString(), "startTime", "10:30"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("booking.error.conflict"));

        // Outside working hours → 400.
        mvc.perform(post("/bookings").header("Authorization", bearer(oTok)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.profile().getId(),
                                "serviceId", p.service().getId(), "bookingType", "SCHEDULED",
                                "bookingDate", day.toString(), "startTime", "23:00"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.outside_working_hours"));

        // Another customer can't read it (403, not 400).
        mvc.perform(get("/bookings/" + id).header("Authorization", bearer(oTok)))
                .andExpect(status().isForbidden());

        // Status filter (BE-9) and no contact before acceptance (BE-16).
        mvc.perform(get("/bookings/provider?status=PENDING").header("Authorization", bearer(pTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[0].id").value(id))
                .andExpect(jsonPath("$.data.content[0].customer.phone").doesNotExist());
        mvc.perform(get("/bookings/provider?status=COMPLETED").header("Authorization", bearer(pTok)))
                .andExpect(jsonPath("$.data.totalElements").value(0));
        mvc.perform(get("/bookings/" + id + "/contact").header("Authorization", bearer(cTok)))
                .andExpect(status().isBadRequest());

        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(pTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.provider.ownerName").value(p.user().getFullName()));
        mvc.perform(get("/bookings/" + id + "/contact").header("Authorization", bearer(cTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(p.user().getPhone()));

        mvc.perform(patch("/bookings/" + id + "/in-progress").header("Authorization", bearer(pTok)))
                .andExpect(status().isOk());
        mvc.perform(patch("/bookings/" + id + "/complete").header("Authorization", bearer(pTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("COMPLETED"))
                .andExpect(jsonPath("$.data.commissionAmount").value(30.0));

        // Customer reviews; provider rates the customer; only the customer review is public (BE-6).
        mvc.perform(post("/reviews").header("Authorization", bearer(cTok)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingId", id, "rating", 5, "comment", "Great"))))
                .andExpect(status().isCreated());
        mvc.perform(post("/reviews").header("Authorization", bearer(pTok)).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingId", id, "rating", 2,
                                "comment", "Late", "direction", "PROVIDER_TO_CUSTOMER"))))
                .andExpect(status().isCreated());
        JsonNode reviews = data(mvc.perform(get("/providers/" + p.profile().getId() + "/reviews"))
                .andExpect(status().isOk()));
        assertThat(reviews.get("totalElements").asInt()).isEqualTo(1);
        long reviewId = reviews.get("content").get(0).get("id").asLong();
        assertThat(reviews.get("content").get(0).get("serviceName").asText()).isEqualTo("Haircut");

        // Provider reply (BE-18) shows publicly.
        mvc.perform(post("/provider/reviews/" + reviewId + "/reply").header("Authorization", bearer(pTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("reply", "Thank you!"))))
                .andExpect(status().isOk());
        mvc.perform(get("/providers/" + p.profile().getId() + "/reviews"))
                .andExpect(jsonPath("$.data.content[0].reply").value("Thank you!"));

        // Discovery shows the real starting price (BE-15).
        mvc.perform(get("/providers/search?q=" + "Studio " + p.user().getId()))
                .andExpect(jsonPath("$.data.content[0].startingPrice").value(300.0));
    }

    @Test
    void cancellationReasonIsStoredAndTheProviderIsNotified() throws Exception {
        Provider p = approvedProvider();
        User customer = user(UserRole.CUSTOMER);
        long id = book(login(customer), p, LocalDate.now().plusDays(3), LocalTime.of(12, 0));

        mvc.perform(patch("/bookings/" + id + "/cancel?reason=Change of plans")
                        .header("Authorization", bearer(login(customer))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.cancellationReason").value("Change of plans"));

        assertThat(notificationRepo.findByUserIdOrderByCreatedAtDesc(p.user().getId(),
                        org.springframework.data.domain.PageRequest.of(0, 10)).getContent())
                .anyMatch(n -> n.getType() == NotificationType.BOOKING_CANCELLED);
    }

    // ── safety ───────────────────────────────────────────────────────────────

    @Test
    void sosAlertsSupportAndContactsButIsHiddenFromTheOtherParty() throws Exception {
        Provider p = approvedProvider();
        User customer = user(UserRole.CUSTOMER);
        User support = user(UserRole.ADMIN, AdminPermission.SUPPORT);
        trustedContactRepo.save(TrustedContact.builder().user(customer).name("Sister").phone("+201099999999").build());
        String cTok = login(customer), pTok = login(p.user());
        long id = book(cTok, p, LocalDate.now().plusDays(1), LocalTime.of(15, 0));
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(pTok))).andExpect(status().isOk());

        long eventId = data(mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("type", "SOS", "latitude", 30.05, "longitude", 31.23))))
                .andExpect(status().isCreated())).get("id").asLong();

        // Trusted contact texted; the provider is not told and can't see it.
        verify(smsService).send(eq("+201099999999"), contains("SOS"));
        mvc.perform(get("/bookings/" + id + "/safety").header("Authorization", bearer(pTok)))
                .andExpect(jsonPath("$.data.length()").value(0));
        assertThat(notificationRepo.findByUserIdOrderByCreatedAtDesc(p.user().getId(),
                        org.springframework.data.domain.PageRequest.of(0, 20)).getContent())
                .noneMatch(n -> n.getType() == NotificationType.SAFETY_ALERT);

        // Support sees it in the queue.
        String sTok = login(support);
        mvc.perform(get("/admin/safety").header("Authorization", bearer(sTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content[?(@.id == " + eventId + ")].actorRole").value("CUSTOMER"));

        // Provider can't close someone else's SOS; the customer can ("I'm safe").
        mvc.perform(post("/bookings/" + id + "/safety/" + eventId + "/resolve").header("Authorization", bearer(pTok)))
                .andExpect(status().isForbidden());
        mvc.perform(post("/bookings/" + id + "/safety/" + eventId + "/resolve").header("Authorization", bearer(cTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resolved").value(true));
    }

    // ── account & notifications ──────────────────────────────────────────────

    @Test
    void addressEditingKeepsASingleDefaultAndOwnership() throws Exception {
        User u = user(UserRole.CUSTOMER);
        User stranger = user(UserRole.CUSTOMER);
        String tok = login(u);
        long first = data(mvc.perform(post("/account/addresses").header("Authorization", bearer(tok))
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("label", "Home", "addressLine", "1 Nile St"))))).get("id").asLong();
        long second = data(mvc.perform(post("/account/addresses").header("Authorization", bearer(tok))
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("label", "Work", "addressLine", "2 Tahrir Sq"))))).get("id").asLong();

        mvc.perform(put("/account/addresses/" + second).header("Authorization", bearer(tok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("label", "Office", "addressLine", "2 Tahrir Sq",
                                "defaultAddress", true))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.label").value("Office"));
        JsonNode list = data(mvc.perform(get("/account/addresses").header("Authorization", bearer(tok))));
        assertThat(list.size()).isEqualTo(2);
        assertThat(list.get(0).get("id").asLong()).isEqualTo(second);
        assertThat(list.get(1).get("defaultAddress").asBoolean()).isFalse();

        mvc.perform(put("/account/addresses/" + first).header("Authorization", bearer(login(stranger)))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("label", "Mine", "addressLine", "x"))))
                .andExpect(status().isNotFound());
    }

    @Test
    void oneNotificationCanBeMarkedReadOnlyByItsOwner() throws Exception {
        User u = user(UserRole.CUSTOMER);
        User stranger = user(UserRole.CUSTOMER);
        Notification n = notificationRepo.save(Notification.builder().user(u).type(NotificationType.BOOKING_REMINDER)
                .titleEn("t").titleAr("t").read(false).build());

        mvc.perform(patch("/notifications/" + n.getId() + "/read").header("Authorization", bearer(login(stranger))))
                .andExpect(status().isNotFound());
        mvc.perform(put("/notifications/" + n.getId() + "/read").header("Authorization", bearer(login(u))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.read").value(true));
    }

    // ── files ────────────────────────────────────────────────────────────────

    @Test
    void publicFilesNeedNoTokenAndPrivatePathsCantEscape() throws Exception {
        Path file = Path.of("uploads/public/gallery/it-test.png");
        Files.createDirectories(file.getParent());
        Files.write(file, new byte[]{(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A});
        try {
            mvc.perform(get("/files/public/gallery/it-test.png")).andExpect(status().isOk());
        } finally {
            Files.deleteIfExists(file);
        }

        String admin = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        mvc.perform(get("/admin/verification/document")
                        .param("filePath", "uploads/private/../../pom.xml")
                        .header("Authorization", bearer(admin)))
                .andExpect(status().isForbidden());
    }

    @Test
    void anUploadThatIsNotReallyAnImageIsRejected() throws Exception {
        Provider p = approvedProvider();
        MockMultipartFile fake = new MockMultipartFile("image", "evil.html", "image/png",
                "<html><script>alert(1)</script></html>".getBytes());
        mvc.perform(multipart("/provider/gallery").file(fake).header("Authorization", bearer(login(p.user()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("upload.error.invalid_type"));
    }
}
