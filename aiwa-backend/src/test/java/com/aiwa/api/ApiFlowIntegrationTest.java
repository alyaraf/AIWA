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
    @Autowired CommissionLedgerRepository ledgerRepo;
    @Autowired GalleryImageRepository galleryRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired io.micrometer.core.instrument.MeterRegistry meterRegistry;
    @Autowired SavedAddressRepository savedAddressRepo;
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
    void adminUserSearchCombinesRoleAndQueryOnTheServer() throws Exception {
        String tag = "qzx" + SEQ.incrementAndGet();
        User customer = user(UserRole.CUSTOMER);
        customer.setFullName("Nour " + tag);
        userRepo.save(customer);
        User provider = user(UserRole.PROVIDER);
        provider.setFullName("Nour " + tag + " Studio");
        userRepo.save(provider);
        String admin = login(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));

        // OPS-8: before, q ignored role and the panel filtered 500 rows in the browser.
        JsonNode both = data(mvc.perform(get("/admin/users").param("q", tag.toUpperCase()).param("size", "5")
                .header("Authorization", bearer(admin))).andExpect(status().isOk()));
        assertThat(both.get("totalElements").asInt()).isEqualTo(2);
        // Newest first.
        assertThat(both.get("content").get(0).get("id").asLong()).isEqualTo(provider.getId());

        JsonNode providersOnly = data(mvc.perform(get("/admin/users").param("q", tag).param("role", "provider")
                .header("Authorization", bearer(admin))).andExpect(status().isOk()));
        assertThat(providersOnly.get("totalElements").asInt()).isEqualTo(1);
        assertThat(providersOnly.get("content").get(0).get("id").asLong()).isEqualTo(provider.getId());

        JsonNode paged = data(mvc.perform(get("/admin/users").param("q", tag).param("size", "1").param("page", "1")
                .header("Authorization", bearer(admin))).andExpect(status().isOk()));
        assertThat(paged.get("content").get(0).get("id").asLong()).isEqualTo(customer.getId());
        assertThat(paged.get("totalPages").asInt()).isEqualTo(2);
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

        // R2-17: a visit can't be started two days early.
        mvc.perform(patch("/bookings/" + id + "/in-progress").header("Authorization", bearer(pTok)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.too_early_for_step"));
        // Bring the appointment to half an hour from now, then it can start.
        com.aiwa.entity.Booking live = bookingRepo.findById(id).orElseThrow();
        java.time.LocalDateTime soon = com.aiwa.util.AiwaTime.now().plusMinutes(30).withSecond(0).withNano(0);
        live.setBookingDate(soon.toLocalDate());
        live.setStartTime(soon.toLocalTime());
        live.setEndTime(soon.toLocalTime().plusMinutes(30));
        bookingRepo.save(live);
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
        double sosBefore = meterRegistry.counter("aiwa.sos.alerts").count();

        long eventId = data(mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("type", "SOS", "latitude", 30.05, "longitude", 31.23))))
                .andExpect(status().isCreated())).get("id").asLong();
        // OPS-5: the monitoring alert rule fires on this counter.
        assertThat(meterRegistry.counter("aiwa.sos.alerts").count()).isEqualTo(sosBefore + 1);

        // Trusted contact texted; the provider is not told and can't see it.
        // Texts go out on the background pool after commit (BE-37).
        verify(smsService, timeout(5000)).send(eq("+201099999999"), contains("SOS"));
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
    void supportCanDeleteACustomerWhoHasBookingsAndTheirDataIsErased() throws Exception {
        Provider p = approvedProvider();
        User customer = user(UserRole.CUSTOMER);
        String cTok = login(customer);
        book(cTok, p, LocalDate.now().plusDays(2), LocalTime.of(11, 0));
        SavedAddress home = savedAddressRepo.save(SavedAddress.builder().user(customer).label("Home")
                .addressLine("12 Nile St, Zamalek").latitude(30.06).longitude(31.22).build());
        String admin = login(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));

        // OPS-4: this used to be a hard delete that failed on the booking row.
        mvc.perform(delete("/admin/users/" + customer.getId()).header("Authorization", bearer(admin)))
                .andExpect(status().isOk());

        User after = userRepo.findById(customer.getId()).orElseThrow();
        assertThat(after.isActive()).isFalse();
        assertThat(after.getEmail()).isNull();
        assertThat(after.getPhone()).isNull();
        assertThat(after.getFullName()).isEqualTo("Deleted user");
        SavedAddress scrubbed = savedAddressRepo.findById(home.getId()).orElseThrow();
        assertThat(scrubbed.getAddressLine()).isEqualTo("Deleted");
        assertThat(scrubbed.getLatitude()).isNull();
        assertThat(bookingRepo.findByCustomerIdAndStatus(customer.getId(), BookingStatus.PENDING)).isEmpty();
        // Their old session is dead too.
        mvc.perform(get("/auth/me").header("Authorization", bearer(cTok))).andExpect(status().isUnauthorized());
    }

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
    void nearbySearchUsesTheRadiusAndDropsAProviderSuspendedAfterCaching() throws Exception {
        Provider near = approvedProvider();                    // Zamalek, Cairo
        Provider far = approvedProvider();
        far.profile().setLatitude(31.20);                       // Alexandria, ~180 km away
        far.profile().setLongitude(29.92);
        providerRepo.save(far.profile());

        java.util.function.Supplier<java.util.List<Long>> search = () -> {
            try {
                JsonNode page = data(mvc.perform(get("/providers/nearby")
                        .param("lat", "30.0551").param("lng", "31.2201").param("radiusKm", "10").param("size", "100")));
                return java.util.stream.StreamSupport.stream(page.get("content").spliterator(), false)
                        .map(n -> n.get("id").asLong()).toList();
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        };
        assertThat(search.get()).contains(near.profile().getId()).doesNotContain(far.profile().getId());

        // Suspended after the ids were cached: must not keep showing.
        ProviderProfile p = providerRepo.findById(near.profile().getId()).orElseThrow();
        p.setVerificationStatus(VerificationStatus.SUSPENDED);
        providerRepo.save(p);
        assertThat(search.get()).doesNotContain(near.profile().getId());
    }

    @Test
    void aStaleBookingWriteIsRejectedNotSilentlyApplied() throws Exception {
        Provider p = approvedProvider();
        User c = user(UserRole.CUSTOMER);
        long id = book(login(c), p, LocalDate.now().plusDays(3), LocalTime.of(11, 0));
        Booking stale = bookingRepo.findById(id).orElseThrow(); // detached copy, version v

        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(login(p.user()))))
                .andExpect(status().isOk()); // version v+1

        stale.setStatus(BookingStatus.CANCELLED);
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> bookingRepo.save(stale))
                .isInstanceOf(org.springframework.orm.ObjectOptimisticLockingFailureException.class);
        assertThat(bookingRepo.findById(id).orElseThrow().getStatus()).isEqualTo(BookingStatus.ACCEPTED);
    }

    // ── cross-app handoffs (provider app → admin panel) ──────────────────────

    @Test
    void publishingNewTermsMakesUsersReaccept() throws Exception {
        String superAdmin = login(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        String version = "it-" + SEQ.incrementAndGet();
        mvc.perform(post("/terms").header("Authorization", bearer(superAdmin))
                        .param("version", version).param("type", "CUSTOMER_TERMS")
                        .param("contentEn", "New customer terms").param("contentAr", "شروط جديدة"))
                .andExpect(status().isCreated());

        String customer = login(user(UserRole.CUSTOMER));
        mvc.perform(get("/auth/me").header("Authorization", bearer(customer)))
                .andExpect(jsonPath("$.data.termsUpToDate").value(false));
        mvc.perform(post("/terms/accept").param("version", version).header("Authorization", bearer(customer)))
                .andExpect(status().isOk());
        mvc.perform(get("/auth/me").header("Authorization", bearer(customer)))
                .andExpect(jsonPath("$.data.termsUpToDate").value(true));
    }

    @Test
    void aReportedCommissionPaymentReachesFinanceAndClearsOnConfirm() throws Exception {
        Provider p = approvedProvider();
        ledgerRepo.save(CommissionLedgerEntry.builder().provider(p.profile())
                .bookingAmount(new BigDecimal("300")).commissionPercent(new BigDecimal("10"))
                .commissionAmount(new BigDecimal("30")).status(LedgerEntryStatus.DUE).build());

        mvc.perform(patch("/provider/settlement/pay").header("Authorization", bearer(login(p.user()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.paymentReportedAt").isNotEmpty());

        String finance = login(user(UserRole.ADMIN, AdminPermission.FINANCE));
        String inboxId = "settlement-" + p.profile().getId();
        JsonNode inbox = data(mvc.perform(get("/admin/inbox").param("limit", "50")
                .header("Authorization", bearer(finance))));
        assertThat(inbox.findValuesAsText("id")).contains(inboxId);
        JsonNode rows = data(mvc.perform(get("/admin/settlements/providers").header("Authorization", bearer(finance))));
        // DR-028: a page of rows, totals summed in the database.
        JsonNode row = java.util.stream.StreamSupport.stream(rows.get("content").spliterator(), false)
                .filter(r -> r.get("providerId").asLong() == p.profile().getId()).findFirst().orElseThrow();
        assertThat(row.get("paymentReportedAt").isNull()).isFalse();
        assertThat(row.get("balanceOwed").decimalValue()).isPositive();
        assertThat(row.get("status").asText()).isIn("WITHIN_LIMIT", "OVERDUE");
        assertThat(data(mvc.perform(get("/admin/settlements/overview").header("Authorization", bearer(finance))))
                .get("totalOwed").decimalValue()).isPositive();

        // The ledger export is streamed page by page and still contains this provider.
        MvcResult export = mvc.perform(get("/admin/settlements/export").header("Authorization", bearer(finance)))
                .andExpect(request().asyncStarted()).andReturn();
        String csv = mvc.perform(asyncDispatch(export)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(csv).startsWith("id,providerId,").contains("," + p.profile().getId() + ",");

        mvc.perform(post("/admin/settlements/provider/{id}/confirm-payout", p.profile().getId())
                        .header("Authorization", bearer(finance)))
                .andExpect(status().isOk());
        inbox = data(mvc.perform(get("/admin/inbox").param("limit", "50").header("Authorization", bearer(finance))));
        assertThat(inbox.findValuesAsText("id")).doesNotContain(inboxId);
    }

    @Test
    void aCustomerCanReportAGalleryPhotoIntoPhotoModeration() throws Exception {
        Provider p = approvedProvider();
        GalleryImage img = galleryRepo.save(GalleryImage.builder().provider(p.profile())
                .url("/files/public/gallery/it-photo.jpg").build());

        // Public detail exposes the id the app needs to report a photo.
        JsonNode detail = data(mvc.perform(get("/providers/{id}", p.profile().getId())));
        assertThat(detail.get("gallery").get(0).get("id").asLong()).isEqualTo(img.getId());

        mvc.perform(post("/providers/{pid}/gallery/{iid}/report", p.profile().getId(), img.getId())
                        .param("reason", "Spam or fake account"))
                .andExpect(status().isUnauthorized()); // signed-in users only
        String customer = login(user(UserRole.CUSTOMER));
        mvc.perform(post("/providers/{pid}/gallery/{iid}/report", p.profile().getId(), img.getId())
                        .param("reason", "Spam or fake account").header("Authorization", bearer(customer)))
                .andExpect(status().isOk());

        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        JsonNode queue = data(mvc.perform(get("/admin/moderation").header("Authorization", bearer(support))));
        assertThat(queue.findValuesAsText("imageUrl")).contains("/files/public/gallery/it-photo.jpg");
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

    // ── 2026-10-01 deployment-readiness review: reproduced findings ──────────
    // (marker: Review2Regression)

    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;
    @Autowired com.aiwa.service.impl.BookingServiceImpl bookingService;

    /** V-01: an email set to someone's phone number used to capture that person's sign-in. */
    @Test
    void anEmailCannotBeSetToAnotherUsersPhoneNumber() throws Exception {
        User victim = userRepo.save(User.builder().fullName("Victim").phone(uniquePhone())
                .password(encoder.encode(PASSWORD)).role(UserRole.CUSTOMER).active(true).termsAccepted(true).build());
        User attacker = user(UserRole.CUSTOMER);

        mvc.perform(patch("/auth/me").header("Authorization", bearer(login(attacker)))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("fullName", "A", "email", victim.getPhone()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.invalid_email"));

        // The victim's phone still signs in to the victim's own account.
        String access = tokens(victim.getPhone()).get("accessToken").asText();
        mvc.perform(get("/auth/me").header("Authorization", bearer(access)))
                .andExpect(jsonPath("$.data.id").value(victim.getId()));
    }

    /** R2-19: the same number typed the local way signs in to the same account. */
    @Test
    void aPhoneTypedInLocalFormatSignsInToTheSameAccount() throws Exception {
        User u = user(UserRole.CUSTOMER);                     // stored as +2010XXXXXXXX
        String local = "0" + u.getPhone().substring(3);        // 010XXXXXXXX
        String access = tokens(local).get("accessToken").asText();
        mvc.perform(get("/auth/me").header("Authorization", bearer(access)))
                .andExpect(jsonPath("$.data.id").value(u.getId()));
    }

    /** CR-02: a number support saves the local way is stored as +20…, so the user can still sign in and reset by phone. */
    @Test
    void aPhoneSavedBySupportInLocalFormatStillSignsInAndResets() throws Exception {
        User u = user(UserRole.CUSTOMER);
        String support = login(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        String e164 = uniquePhone();                           // +2010XXXXXXXX
        String local = "0" + e164.substring(3);                // 010XXXXXXXX

        mvc.perform(patch("/admin/users/" + u.getId()).header("Authorization", bearer(support))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", local))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.phone").value(e164));
        assertThat(userRepo.findById(u.getId()).orElseThrow().getPhone()).isEqualTo(e164);

        // Sign-in by phone, typed either way.
        tokens(local);
        tokens(e164);

        // Reset by phone.
        mvc.perform(post("/auth/send-otp").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", local))))
                .andExpect(status().isOk());
        ArgumentCaptor<String> code = ArgumentCaptor.forClass(String.class);
        verify(smsService).sendOtp(eq(e164), code.capture(), anyInt());
        mvc.perform(post("/auth/reset-password").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", local,
                                "code", code.getValue(), "newPassword", "Another456!"))))
                .andExpect(status().isOk());
        mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", local, "password", "Another456!"))))
                .andExpect(status().isOk());

        // The number is taken, however the next person types it.
        User other = user(UserRole.CUSTOMER);
        mvc.perform(patch("/admin/users/" + other.getId()).header("Authorization", bearer(support))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", local))))
                .andExpect(status().isBadRequest());
    }

    /** CR-02: admin email fields must hold an email, stored and compared in one spelling. */
    @Test
    void anAdminEmailMustBeAnEmailAndUniqueWhateverItsCase() throws Exception {
        String boss = login(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        User customer = user(UserRole.CUSTOMER);
        int n = SEQ.incrementAndGet();
        String e164 = uniquePhone();
        java.util.function.BiFunction<String, String, String> newAdmin = (email, phone) -> {
            try {
                return json.writeValueAsString(Map.of("fullName", "Ops " + n, "email", email, "phone", phone,
                        "password", "AdminPassword123!", "permissions", java.util.List.of("SUPPORT")));
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
        };

        mvc.perform(post("/admin/users/admins").header("Authorization", bearer(boss))
                        .contentType(MediaType.APPLICATION_JSON).content(newAdmin.apply("not-an-email", "")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.invalid_email"));
        mvc.perform(patch("/admin/users/" + customer.getId()).header("Authorization", bearer(boss))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", customer.getPhone()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.invalid_email"));

        mvc.perform(post("/admin/users/admins").header("Authorization", bearer(boss))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(newAdmin.apply("Ops" + n + "@Test.AIWA", "0" + e164.substring(3))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.email").value("ops" + n + "@test.aiwa"))
                .andExpect(jsonPath("$.data.phone").value(e164));
        mvc.perform(post("/admin/users/admins").header("Authorization", bearer(boss))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(newAdmin.apply("OPS" + n + "@test.aiwa", "")))
                .andExpect(status().isBadRequest());
        assertThat(userRepo.findByEmailIgnoreCase("ops" + n + "@test.aiwa")).isPresent();
    }

    /** CR-02: Flyway only runs the V19 Java migration because it is a bean. */
    @Test
    void theIdentifierMigrationIsRegisteredAsVersion19(@Autowired org.springframework.context.ApplicationContext ctx) {
        assertThat(ctx.getBeansOfType(org.flywaydb.core.api.migration.JavaMigration.class).values())
                .extracting(m -> m.getVersion().getVersion()).containsExactly("19");
    }

    /** DR-013: a client can't point its avatar at another user's stored image. */
    @Test
    void anAvatarUrlCannotBeClaimedFromSomeoneElse() throws Exception {
        User owner = user(UserRole.CUSTOMER);
        owner.setProfileImageUrl("/files/public/avatars/owner.jpg");
        userRepo.save(owner);
        User other = user(UserRole.CUSTOMER);

        mvc.perform(patch("/auth/me").header("Authorization", bearer(login(other)))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("fullName", "B",
                                "profileImageUrl", "/files/public/avatars/owner.jpg"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.avatar_url_not_allowed"));
    }

    /** DR-007: a SUPPORT-only admin used to be able to suspend a super admin (reproduced: 200). */
    @Test
    void aSupportAdminCannotDeactivateASuperAdmin() throws Exception {
        User boss = user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN);
        User support = user(UserRole.ADMIN, AdminPermission.SUPPORT);

        mvc.perform(patch("/admin/users/" + boss.getId() + "/deactivate").header("Authorization", bearer(login(support))))
                .andExpect(status().isBadRequest());
        assertThat(userRepo.findById(boss.getId()).orElseThrow().isActive()).isTrue();

        // Customers stay a SUPPORT action.
        User customer = user(UserRole.CUSTOMER);
        mvc.perform(patch("/admin/users/" + customer.getId() + "/deactivate").header("Authorization", bearer(login(support))))
                .andExpect(status().isOk());
    }

    /** DR-017: turning 2FA setup on or off needs the password, not just a session. */
    @Test
    void twoFactorSetupNeedsThePassword() throws Exception {
        String tok = login(user(UserRole.CUSTOMER));
        mvc.perform(post("/auth/2fa/setup").header("Authorization", bearer(tok))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"password\":\"wrong\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.wrong_password"));
        mvc.perform(post("/auth/2fa/setup").header("Authorization", bearer(tok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD))))
                .andExpect(status().isOk());
    }

    /** R2-07: the travel buffer applies after an existing booking too (10:00 then 11:00 both fitted). */
    @Test
    void theTravelBufferKeepsAGapAfterAnExistingBooking() throws Exception {
        Provider p = approvedProvider();
        p.profile().setTravelBufferMinutes(120);
        providerRepo.save(p.profile());
        LocalDate day = LocalDate.now().plusDays(4);
        book(login(user(UserRole.CUSTOMER)), p, day, LocalTime.of(10, 0));     // 10:00–11:00

        mvc.perform(post("/bookings").header("Authorization", bearer(login(user(UserRole.CUSTOMER))))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.profile().getId(),
                                "serviceId", p.service().getId(), "bookingType", "SCHEDULED",
                                "bookingDate", day.toString(), "startTime", "11:00"))))
                .andExpect(status().isConflict());
        book(login(user(UserRole.CUSTOMER)), p, day, LocalTime.of(13, 0));    // 2 h after 11:00: fine
    }

    /** DR-014: a suspended owner account no longer receives bookings. */
    @Test
    void aSuspendedProviderAccountReceivesNoBookings() throws Exception {
        Provider p = approvedProvider();
        p.user().setActive(false);
        userRepo.save(p.user());
        mvc.perform(post("/bookings").header("Authorization", bearer(login(user(UserRole.CUSTOMER))))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", p.profile().getId(),
                                "serviceId", p.service().getId(), "bookingType", "SCHEDULED",
                                "bookingDate", LocalDate.now().plusDays(2).toString(), "startTime", "10:00"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.provider_unavailable"));
    }

    /** R2-11: the owner's phone only goes to customers with a live booking. */
    @Test
    void theProviderPhoneIsNotShownWithoutALiveBooking() throws Exception {
        Provider p = approvedProvider();
        String cTok = login(user(UserRole.CUSTOMER));
        mvc.perform(get("/providers/" + p.profile().getId()).header("Authorization", bearer(cTok)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.owner.phone").doesNotExist());

        long id = book(cTok, p, LocalDate.now().plusDays(2), LocalTime.of(10, 0));
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(login(p.user()))))
                .andExpect(status().isOk());
        mvc.perform(get("/providers/" + p.profile().getId()).header("Authorization", bearer(cTok)))
                .andExpect(jsonPath("$.data.owner.phone").value(p.user().getPhone()));

        // A listing that isn't approved is not served to customers at all.
        p.profile().setVerificationStatus(VerificationStatus.SUSPENDED);
        providerRepo.save(p.profile());
        mvc.perform(get("/providers/" + p.profile().getId()).header("Authorization", bearer(cTok)))
                .andExpect(status().isNotFound());
    }

    /** R2-01: rescheduling a booking accepted long ago no longer makes the next sweep expire it. */
    @Test
    void aRescheduledAcceptedBookingIsNotExpiredAtOnce() throws Exception {
        Provider p = approvedProvider();
        String cTok = login(user(UserRole.CUSTOMER));
        long id = book(cTok, p, LocalDate.now().plusDays(5), LocalTime.of(10, 0));
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(login(p.user()))))
                .andExpect(status().isOk());
        // Accepted three days ago.
        jdbc.update("UPDATE bookings SET created_at = ? WHERE id = ?",
                java.sql.Timestamp.valueOf(java.time.LocalDateTime.now().minusDays(3)), id);

        mvc.perform(patch("/bookings/" + id + "/reschedule").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("bookingDate", LocalDate.now().plusDays(6).toString(),
                                "startTime", "11:00"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("PENDING"));

        bookingService.expireStalePendingBookings();
        assertThat(bookingRepo.findById(id).orElseThrow().getStatus()).isEqualTo(BookingStatus.PENDING);
    }

    /**
     * R2-08 (reproduced on PostgreSQL): after an admin wrote a dispute off, the
     * customer's "paid" re-created the commission. The ledger now follows the outcome.
     */
    @Test
    void aWrittenOffDisputeKeepsNoCommission() throws Exception {
        Provider p = approvedProvider();
        String cTok = login(user(UserRole.CUSTOMER)), pTok = login(p.user());
        long id = book(cTok, p, LocalDate.now().plusDays(2), LocalTime.of(10, 0));
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(pTok))).andExpect(status().isOk());
        com.aiwa.entity.Booking live = bookingRepo.findById(id).orElseThrow();
        java.time.LocalDateTime soon = com.aiwa.util.AiwaTime.now().plusMinutes(30).withSecond(0).withNano(0);
        live.setBookingDate(soon.toLocalDate());
        live.setStartTime(soon.toLocalTime());
        live.setEndTime(soon.toLocalTime().plusMinutes(60));
        bookingRepo.save(live);
        mvc.perform(patch("/bookings/" + id + "/in-progress").header("Authorization", bearer(pTok))).andExpect(status().isOk());
        mvc.perform(patch("/bookings/" + id + "/complete").header("Authorization", bearer(pTok))).andExpect(status().isOk());
        assertThat(ledgerRepo.findByBookingId(id).orElseThrow().getStatus()).isEqualTo(LedgerEntryStatus.DUE);

        // Customer says it wasn't paid: commission is held while disputed.
        mvc.perform(patch("/bookings/" + id + "/confirm-payment?paid=false").header("Authorization", bearer(cTok)))
                .andExpect(status().isOk());
        assertThat(ledgerRepo.findByBookingId(id).orElseThrow().getStatus()).isEqualTo(LedgerEntryStatus.VOID);

        String fTok = login(user(UserRole.ADMIN, AdminPermission.FINANCE));
        mvc.perform(post("/admin/bookings/" + id + "/resolve-dispute?outcome=UNPAID").header("Authorization", bearer(fTok)))
                .andExpect(status().isOk());

        // The customer can't reopen or re-charge it.
        mvc.perform(patch("/bookings/" + id + "/confirm-payment?paid=true").header("Authorization", bearer(cTok)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.payment_already_resolved"));
        mvc.perform(patch("/bookings/" + id + "/confirm-payment?paid=false").header("Authorization", bearer(cTok)))
                .andExpect(status().isBadRequest());
        assertThat(ledgerRepo.findByBookingId(id).orElseThrow().getStatus()).isEqualTo(LedgerEntryStatus.VOID);
    }

    /** BE-37 / R2-03: each SOS text gets a delivery record; a failed send ends as FAILED, shown to the user. */
    @Test
    void sosTextsAreTrackedPerRecipient() throws Exception {
        Provider p = approvedProvider();
        User customer = user(UserRole.CUSTOMER);
        trustedContactRepo.save(TrustedContact.builder().user(customer).name("Brother").phone("+201088888888").build());
        doThrow(new RuntimeException("gateway down")).when(smsService).send(eq("+201088888888"), anyString());
        String cTok = login(customer);
        long id = book(cTok, p, LocalDate.now().plusDays(1), LocalTime.of(15, 0));
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", bearer(login(p.user())))).andExpect(status().isOk());

        mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("type", "SOS"))))
                .andExpect(status().isCreated());

        // Three attempts (2 s + 4 s back-off), then FAILED; the app's view says so.
        verify(smsService, timeout(15000).times(3)).send(eq("+201088888888"), anyString());
        org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(5)).untilAsserted(() ->
                mvc.perform(get("/bookings/" + id + "/safety").header("Authorization", bearer(cTok)))
                        .andExpect(jsonPath("$.data[0].contactsFailed").value(1))
                        .andExpect(jsonPath("$.data[0].contactsTexted").value(0)));

        // Pressing SOS again doesn't text everyone again; it returns the open alert.
        mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("type", "SOS"))))
                .andExpect(status().isCreated());
        verify(smsService, after(500).times(3)).send(eq("+201088888888"), anyString());
    }

    /** DR-028: an SOS outside a live booking (here: one never accepted) is refused. */
    @Test
    void sosIsOnlyAvailableAroundALiveBooking() throws Exception {
        Provider p = approvedProvider();
        String cTok = login(user(UserRole.CUSTOMER));
        long id = book(cTok, p, LocalDate.now().plusDays(3), LocalTime.of(10, 0));
        mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", bearer(cTok))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("type", "SOS"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("safety.error.sos_not_live"));
    }

}
