package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.*;
import com.aiwa.enums.*;
import com.aiwa.repository.*;
import com.aiwa.service.SmsService;
import com.aiwa.util.AiwaTime;
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
import java.time.LocalDateTime;
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
 * CR-21: policy text and free-text notes travel in a JSON body, not the URL; the
 * old request parameters still work. One test per area, each posting the body
 * and, where it matters, the legacy parameter.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FreeTextBodiesApiTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final AtomicInteger SLOT = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired AvailabilityRepository availabilityRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired TermsPolicyRepository termsRepo;
    @Autowired ModerationCaseRepository moderationRepo;
    @Autowired GalleryImageRepository galleryRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @MockBean SmsService smsService;

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    // ── fixtures ─────────────────────────────────────────────────────────────

    private User user(UserRole role, AdminPermission... perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("ft " + n).email("ft" + n + "@freetext.aiwa")
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

    private record Provider(User user, ProviderProfile profile, com.aiwa.entity.Service service) {}

    private Provider provider(VerificationStatus verification) {
        User u = user(UserRole.PROVIDER);
        ProviderProfile p = providerRepo.save(ProviderProfile.builder()
                .user(u).businessName("Free Text Studio " + u.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(verification).travelBufferMinutes(0).build());
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

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    private String body(Map<String, String> fields) throws Exception {
        return json.writeValueAsString(fields);
    }

    /** A pending booking at a time no other booking of this provider uses. */
    private long book(String customerAuth, Provider p) throws Exception {
        int n = SLOT.getAndIncrement();
        LocalDate date = LocalDate.now().plusDays(2 + n / 12);
        LocalTime time = LocalTime.of(8 + n % 12, 0);
        return data(mvc.perform(post("/bookings").header("Authorization", customerAuth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "providerId", p.profile().getId(), "serviceId", p.service().getId(),
                                "bookingType", "SCHEDULED", "bookingDate", date.toString(),
                                "startTime", time.toString(), "homeService", false))))
                .andExpect(status().isCreated())).get("id").asLong();
    }

    private void accept(String providerAuth, long id) throws Exception {
        mvc.perform(patch("/bookings/{id}/accept", id).header("Authorization", providerAuth))
                .andExpect(status().isOk());
    }

    // ── terms ────────────────────────────────────────────────────────────────

    @Test
    void aTwentyKilobyteArabicPolicyPublishesInABody() throws Exception {
        String auth = bearer(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        String arabic = "تلتزم منصة أيوه بحماية بياناتك وخصوصيتك. ".repeat(500); // about 20 KB of UTF-8
        assertThat(arabic.getBytes(java.nio.charset.StandardCharsets.UTF_8).length).isGreaterThan(20_000);

        mvc.perform(post("/terms").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("version", "ft-body-1", "type", "PRIVACY",
                                "contentEn", "English policy", "contentAr", arabic,
                                "changeNote", "Longer Arabic text"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.version").value("ft-body-1"));

        TermsPolicy saved = termsRepo.findByTypeAndVersion("PRIVACY", "ft-body-1").orElseThrow();
        assertThat(saved.getContentAr()).isEqualTo(arabic);
        assertThat(saved.getChangeNote()).isEqualTo("Longer Arabic text");
        assertThat(saved.isActive()).isTrue();
    }

    @Test
    void theOldTermsParametersStillPublishAndMissingContentIsRefused() throws Exception {
        String auth = bearer(user(UserRole.ADMIN, AdminPermission.SUPER_ADMIN));
        mvc.perform(post("/terms").header("Authorization", auth)
                        .param("version", "ft-param-1").param("type", "SAFETY")
                        .param("contentEn", "From parameters").param("contentAr", "من المعاملات"))
                .andExpect(status().isCreated());
        assertThat(termsRepo.findByTypeAndVersion("SAFETY", "ft-param-1").orElseThrow().getContentAr())
                .isEqualTo("من المعاملات");

        mvc.perform(post("/terms").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("version", "ft-none", "type", "SAFETY"))))
                .andExpect(status().isBadRequest());
    }

    // ── complaints ───────────────────────────────────────────────────────────

    @Test
    void complaintsAndWarningsTakeTheirTextFromABody() throws Exception {
        User customer = user(UserRole.CUSTOMER);
        String cAuth = bearer(customer);
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));

        long viaBody = data(mvc.perform(post("/complaints").param("category", "SERVICE_QUALITY")
                        .header("Authorization", cAuth).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("description", "Rude behaviour during the session"))))
                .andExpect(status().isCreated())).get("id").asLong();
        mvc.perform(post("/complaints").param("category", "OTHER").param("description", "From a parameter")
                        .header("Authorization", cAuth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.description").value("From a parameter"));

        mvc.perform(post("/admin/complaints/{id}/resolve", viaBody).header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("notes", "Called both sides"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.description").value("Rude behaviour during the session"))
                .andExpect(jsonPath("$.data.adminNotes").value("Called both sides"));
        mvc.perform(post("/admin/complaints/{id}/resolve", viaBody).param("notes", "Reopened note")
                        .header("Authorization", support))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.adminNotes").value("Reopened note"));
        // A missing note is still refused.
        mvc.perform(post("/admin/complaints/{id}/resolve", viaBody).header("Authorization", support))
                .andExpect(status().isBadRequest());

        mvc.perform(post("/admin/users/{id}/warn", customer.getId()).header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Abusive chat"))))
                .andExpect(status().isOk());
        mvc.perform(post("/admin/users/{id}/warn", customer.getId()).param("reason", "Second warning")
                        .header("Authorization", support))
                .andExpect(status().isOk());
        mvc.perform(post("/admin/users/{id}/flag", customer.getId()).header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Repeated no-shows"))))
                .andExpect(status().isOk());
    }

    // ── bookings ─────────────────────────────────────────────────────────────

    @Test
    void bookingReasonsAndNotesTravelInABody() throws Exception {
        Provider p = provider(VerificationStatus.APPROVED);
        String pAuth = bearer(p.user());
        User customer = user(UserRole.CUSTOMER);
        String cAuth = bearer(customer);
        String finance = bearer(user(UserRole.ADMIN, AdminPermission.FINANCE));

        // Customer cancels with a reason in the body, then with the old parameter.
        long a = book(cAuth, p);
        mvc.perform(patch("/bookings/{id}/cancel", a).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Change of plans"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.cancellationReason").value("Change of plans"));
        long b = book(cAuth, p);
        mvc.perform(patch("/bookings/{id}/cancel", b).param("reason", "Old parameter").header("Authorization", cAuth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.cancellationReason").value("Old parameter"));

        // Provider rejects with a reason in the body; no reason at all is refused.
        long c = book(cAuth, p);
        mvc.perform(patch("/bookings/{id}/reject", c).header("Authorization", pAuth))
                .andExpect(status().isBadRequest());
        mvc.perform(patch("/bookings/{id}/reject", c).header("Authorization", pAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Fully booked that day"))))
                .andExpect(status().isOk());
        assertThat(bookingRepo.findById(c).orElseThrow().getRejectionReason()).isEqualTo("Fully booked that day");

        // Provider completes without cash and explains in the body.
        // (Saved in progress directly: the check-in window keeps a future booking from starting.)
        LocalDateTime soon = AiwaTime.now().plusMinutes(30).withSecond(0).withNano(0);
        long d = bookingRepo.save(Booking.builder().customer(customer).provider(p.profile()).service(p.service())
                .bookingDate(soon.toLocalDate()).startTime(soon.toLocalTime()).endTime(soon.toLocalTime().plusMinutes(60))
                .status(BookingStatus.IN_PROGRESS).totalPrice(new BigDecimal("300"))
                .paymentStatus(PaymentStatus.CASH_PENDING).build()).getId();
        mvc.perform(patch("/bookings/{id}/complete", d).param("cashCollected", "false").header("Authorization", pAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("note", "Customer left without paying"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.completionNote").value("Customer left without paying"));

        // Finance voids that dispute with a reason in the body.
        mvc.perform(post("/admin/bookings/{id}/resolve-dispute", d).param("outcome", "CANCEL")
                        .header("Authorization", finance).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("reason", "Provider agreed to void"))))
                .andExpect(status().isOk());
        assertThat(bookingRepo.findById(d).orElseThrow().getCancellationReason()).isEqualTo("Provider agreed to void");

        // Finance force-cancels another booking with a reason in the body.
        long e = book(cAuth, p);
        mvc.perform(post("/admin/bookings/{id}/force-cancel", e).header("Authorization", finance)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Provider closed the studio"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.cancellationReason").value("Provider closed the studio"));
    }

    // ── safety ───────────────────────────────────────────────────────────────

    @Test
    void sosClosingNotesTravelInABody() throws Exception {
        Provider p = provider(VerificationStatus.APPROVED);
        String pAuth = bearer(p.user());
        String cAuth = bearer(user(UserRole.CUSTOMER));
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));

        long first = book(cAuth, p);
        accept(pAuth, first);
        long own = data(mvc.perform(post("/bookings/{id}/safety", first).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("type", "SOS"))))
                .andExpect(status().isCreated())).get("id").asLong();
        mvc.perform(post("/bookings/{id}/safety/{event}/resolve", first, own).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("notes", "False alarm, I am fine"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resolved").value(true))
                .andExpect(jsonPath("$.data.resolutionNotes").value("False alarm, I am fine"));

        long second = book(cAuth, p);
        accept(pAuth, second);
        long event = data(mvc.perform(post("/bookings/{id}/safety", second).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("type", "SOS"))))
                .andExpect(status().isCreated())).get("id").asLong();
        mvc.perform(post("/admin/safety/{id}/resolve", event).header("Authorization", support))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/admin/safety/{id}/resolve", event).header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("notes", "Called the customer; she is safe."))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.resolutionNotes").value("Called the customer; she is safe."));
    }

    // ── reports and moderation ───────────────────────────────────────────────

    @Test
    void reportsAndModerationNotesTravelInABody() throws Exception {
        Provider p = provider(VerificationStatus.APPROVED);
        String pAuth = bearer(p.user());
        String cAuth = bearer(user(UserRole.CUSTOMER));
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));

        // Reported chat message.
        long booking = book(cAuth, p);
        accept(pAuth, booking);
        long message = data(mvc.perform(post("/bookings/{id}/chat", booking).header("Authorization", cAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("message", "Pay me outside the app"))))
                .andExpect(status().isCreated())).get("id").asLong();
        mvc.perform(post("/bookings/{b}/chat/{m}/report", booking, message).header("Authorization", pAuth)
                        .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("reason", "Asks to pay off-platform"))))
                .andExpect(status().isCreated());
        assertThat(moderationRepo.findAll()).anyMatch(c -> c.getTargetType() == ModerationTargetType.CHAT_MESSAGE
                && c.getTargetId() == message && "Asks to pay off-platform".equals(c.getReason()));

        // Reported gallery photo, then the admin's note on that case.
        GalleryImage image = galleryRepo.save(GalleryImage.builder().provider(p.profile())
                .url("/files/public/gallery/ft-photo.jpg").build());
        mvc.perform(post("/providers/{p}/gallery/{i}/report", p.profile().getId(), image.getId())
                        .header("Authorization", cAuth).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("reason", "Not a photo of the salon"))))
                .andExpect(status().isOk());
        ModerationCase gallery = moderationRepo.findAll().stream()
                .filter(c -> c.getTargetType() == ModerationTargetType.GALLERY_IMAGE && c.getTargetId().equals(image.getId()))
                .findFirst().orElseThrow();
        assertThat(gallery.getReason()).isEqualTo("Not a photo of the salon");

        mvc.perform(patch("/admin/moderation/{id}/action", gallery.getId()).param("status", "ACTIONED")
                        .header("Authorization", support).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("notes", "Hidden: stock photo"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.adminNotes").value("Hidden: stock photo"));
    }

    // ── verification ─────────────────────────────────────────────────────────

    @Test
    void verificationReasonsAndMessagesTravelInABody() throws Exception {
        String support = bearer(user(UserRole.ADMIN, AdminPermission.SUPPORT));
        Provider asked = provider(VerificationStatus.PENDING_VERIFICATION);
        mvc.perform(post("/admin/verification/{id}/request-info", asked.profile().getId())
                        .header("Authorization", support).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("message", "Please upload a clearer licence"))))
                .andExpect(status().isOk());
        assertThat(providerRepo.findById(asked.profile().getId()).orElseThrow().getRejectionReason())
                .isEqualTo("Please upload a clearer licence");

        Provider rejected = provider(VerificationStatus.PENDING_VERIFICATION);
        mvc.perform(post("/admin/verification/{id}/reject", rejected.profile().getId())
                        .header("Authorization", support).contentType(MediaType.APPLICATION_JSON)
                        .content(body(Map.of("reason", "Licence expired"))))
                .andExpect(status().isOk());
        assertThat(providerRepo.findById(rejected.profile().getId()).orElseThrow().getRejectionReason())
                .isEqualTo("Licence expired");

        Provider legacy = provider(VerificationStatus.PENDING_VERIFICATION);
        mvc.perform(post("/admin/verification/{id}/reject", legacy.profile().getId()).param("reason", "Old parameter")
                        .header("Authorization", support))
                .andExpect(status().isOk());
    }
}
