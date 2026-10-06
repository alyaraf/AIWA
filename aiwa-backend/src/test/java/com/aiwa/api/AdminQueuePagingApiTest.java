package com.aiwa.api;

import com.aiwa.entity.Booking;
import com.aiwa.entity.ChatMessage;
import com.aiwa.entity.CommissionLedgerEntry;
import com.aiwa.entity.GalleryImage;
import com.aiwa.entity.ModerationCase;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.SafetyEvent;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.LedgerEntryStatus;
import com.aiwa.enums.ModerationStatus;
import com.aiwa.enums.ModerationTargetType;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.SafetyEventType;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ChatMessageRepository;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.GalleryImageRepository;
import com.aiwa.repository.ModerationCaseRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ReviewRepository;
import com.aiwa.repository.SafetyEventRepository;
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
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * R5 follow-up (AD-13): the six admin queues that still collected every page in the browser (verification, photo
 * moderation, chat reports, reported reviews, settlements, SOS) are searched, filtered and paged ON THE SERVER with the
 * real total, the same permissions and the same ordering rules.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminQueuePagingApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";
    /** A marker no other test uses, so every total below is about these rows only. */
    private final String tag = "pg" + System.nanoTime();

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired ReviewRepository reviewRepo;
    @Autowired GalleryImageRepository galleryRepo;
    @Autowired ChatMessageRepository chatRepo;
    @Autowired ModerationCaseRepository moderationRepo;
    @Autowired CommissionLedgerRepository ledgerRepo;
    @Autowired SafetyEventRepository safetyRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void reset() { ((InMemoryRedisRuntimeService) redis).clear(); }

    private User user(UserRole role, String name, Set<AdminPermission> perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(name)
                .email("pg-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone("+2010774" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms)).build());
    }

    private String login(User u) throws Exception {
        JsonNode d = json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
        return "Bearer " + d.get("accessToken").asText();
    }

    private String support() throws Exception { return login(user(UserRole.ADMIN, "Support " + tag, Set.of(AdminPermission.SUPPORT))); }

    private JsonNode page(String token, String path) throws Exception {
        return json.readTree(mvc.perform(get(path).header("Authorization", token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
    }

    private long total(String token, String path) throws Exception { return page(token, path).get("totalElements").asLong(); }

    private ProviderProfile provider(String owner, String business, String address, VerificationStatus verification) {
        User ownerUser = user(UserRole.PROVIDER, owner, Set.of());
        return providerRepo.save(ProviderProfile.builder().user(ownerUser).businessName(business).address(address)
                .primaryCategory(ServiceCategory.HAIR).verificationStatus(verification).build());
    }

    private Booking booking(User customer, ProviderProfile provider) {
        com.aiwa.entity.Service svc = serviceRepo.save(com.aiwa.entity.Service.builder().provider(provider).name("Cut")
                .category(ServiceCategory.HAIR).price(new BigDecimal("100")).durationMinutes(30).active(true).build());
        return bookingRepo.save(Booking.builder().customer(customer).provider(provider).service(svc)
                .bookingDate(LocalDate.now().minusDays(1)).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                .status(BookingStatus.COMPLETED).totalPrice(new BigDecimal("100")).paymentStatus(PaymentStatus.CASH_CONFIRMED).build());
    }

    private ModerationCase theCase(ModerationTargetType type, Long targetId, String reason, ModerationStatus status) {
        return moderationRepo.save(ModerationCase.builder().targetType(type).targetId(targetId).reason(reason).status(status).build());
    }

    // ── 1. verification ─────────────────────────────────────────────────────────

    @Test
    void verificationQueueIsSearchedAndPagedOnTheServerWithRealTotals() throws Exception {
        for (int i = 0; i < 3; i++) provider("Owner" + i + " " + tag, "Salon" + i + " " + tag, "Street" + i + " Alexandria " + tag, VerificationStatus.PENDING_VERIFICATION);
        provider("Approved Owner " + tag, "Approved Salon " + tag, "Cairo " + tag, VerificationStatus.APPROVED);
        String token = support();

        JsonNode first = page(token, "/admin/verification/pending?query=" + tag + "&size=2&page=0");
        assertThat(first.get("totalElements").asLong()).as("the real total, not what one page holds").isEqualTo(3);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(2);
        assertThat(page(token, "/admin/verification/pending?query=" + tag + "&size=2&page=1").get("content")).hasSize(1);
        // pages are stable (registration order): the three rows are exactly the three, none repeated
        List<String> names = new ArrayList<>();
        page(token, "/admin/verification/pending?query=" + tag + "&size=2&page=0").get("content").forEach(n -> names.add(n.get("businessName").asText()));
        page(token, "/admin/verification/pending?query=" + tag + "&size=2&page=1").get("content").forEach(n -> names.add(n.get("businessName").asText()));
        assertThat(names).doesNotHaveDuplicates().hasSize(3);

        assertThat(total(token, "/admin/verification/pending?query=SALON1 " + tag)).as("business name, case-insensitive").isEqualTo(1);
        assertThat(total(token, "/admin/verification/pending?query=Owner2 " + tag)).as("owner name").isEqualTo(1);
        assertThat(total(token, "/admin/verification/pending?query=Alexandria " + tag)).as("address (shown as the city)").isEqualTo(3);
        assertThat(total(token, "/admin/verification/pending?query=" + tag + " nothing")).isZero();
        // the status tab and the search combine; a pending search never returns the approved provider
        assertThat(total(token, "/admin/verification?status=APPROVED&query=" + tag)).isEqualTo(1);
        assertThat(total(token, "/admin/verification?status=REJECTED&query=" + tag)).isZero();
    }

    // ── 2. photo moderation ─────────────────────────────────────────────────────

    @Test
    void photoModerationIsSearchedAndPagedByTypeOnTheServer() throws Exception {
        ProviderProfile studio = provider("Photo Owner " + tag, "Studio " + tag, "x", VerificationStatus.APPROVED);
        for (int i = 0; i < 3; i++) {
            GalleryImage image = galleryRepo.save(GalleryImage.builder().provider(studio).url("/files/public/gallery/" + tag + i + ".jpg").build());
            theCase(ModerationTargetType.GALLERY_IMAGE, image.getId(), "inappropriate " + tag + " " + i, ModerationStatus.OPEN);
        }
        GalleryImage handled = galleryRepo.save(GalleryImage.builder().provider(studio).url("/files/public/gallery/h" + tag + ".jpg").build());
        theCase(ModerationTargetType.GALLERY_IMAGE, handled.getId(), "inappropriate handled " + tag, ModerationStatus.DISMISSED);
        // a review case never appears in the photo queue
        theCase(ModerationTargetType.REVIEW, 987_654_322L, "inappropriate review " + tag, ModerationStatus.OPEN);
        String token = support();

        String base = "/admin/moderation?type=GALLERY_IMAGE&status=OPEN&query=";
        JsonNode first = page(token, base + tag + "&size=2&page=0");
        assertThat(first.get("totalElements").asLong()).isEqualTo(3);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(2);
        assertThat(page(token, base + tag + "&size=2&page=1").get("content")).hasSize(1);
        assertThat(total(token, base + "INAPPROPRIATE " + tag + " 1")).as("reason, case-insensitive").isEqualTo(1);
        assertThat(total(token, base + "Studio " + tag)).as("the provider's business name").isEqualTo(3);
        assertThat(total(token, "/admin/moderation?type=GALLERY_IMAGE&status=DISMISSED&query=" + tag)).isEqualTo(1);
        // newest first, like before
        JsonNode rows = page(token, base + tag + "&size=3").get("content");
        assertThat(rows.get(0).get("id").asLong()).isGreaterThan(rows.get(2).get("id").asLong());
        // the provider and image fields the screen shows are still filled in
        assertThat(rows.get(0).get("providerName").asText()).isEqualTo("Studio " + tag);
        assertThat(rows.get(0).get("imageUrl").asText()).contains(tag);
    }

    // ── 3 and 4. chat reports and reported reviews ───────────────────────────────

    @Test
    void chatReportsAreSearchedAndPagedAndAnOrphanedCaseIsNotCounted() throws Exception {
        User customer = user(UserRole.CUSTOMER, "Chatter " + tag, Set.of());
        ProviderProfile studio = provider("Chat Owner " + tag, "Chat Studio " + tag, "x", VerificationStatus.APPROVED);
        Booking booking = booking(customer, studio);
        for (int i = 0; i < 3; i++) {
            ChatMessage message = chatRepo.save(ChatMessage.builder().booking(booking).sender(customer).message("rude words " + tag + " " + i).build());
            theCase(ModerationTargetType.CHAT_MESSAGE, message.getId(), "Abusive " + i, ModerationStatus.OPEN);
        }
        theCase(ModerationTargetType.CHAT_MESSAGE, 987_654_321L, "Abusive orphan " + tag, ModerationStatus.OPEN);
        String token = support();

        JsonNode first = page(token, "/admin/chat/moderation?query=" + tag + "&size=2&page=0");
        assertThat(first.get("totalElements").asLong()).as("the orphaned case is neither listed nor counted").isEqualTo(3);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(2);
        assertThat(total(token, "/admin/chat/moderation?query=RUDE WORDS " + tag + " 2")).as("message text").isEqualTo(1);
        assertThat(total(token, "/admin/chat/moderation?query=Chatter " + tag)).as("sender").isEqualTo(3);
        assertThat(total(token, "/admin/chat/moderation?query=" + booking.getId())).as("booking number").isGreaterThanOrEqualTo(3);
        assertThat(first.get("content").get(0).get("senderName").asText()).isEqualTo("Chatter " + tag);
    }

    @Test
    void reportedReviewsAreSearchedAndPagedOnTheServer() throws Exception {
        User customer = user(UserRole.CUSTOMER, "Critic " + tag, Set.of());
        ProviderProfile studio = provider("Rev Owner " + tag, "Rev Studio " + tag, "x", VerificationStatus.APPROVED);
        for (int i = 0; i < 3; i++) {
            Review review = reviewRepo.save(Review.builder().user(customer).provider(studio).booking(booking(customer, studio)).rating(1 + i)
                    .comment(i == 0 ? null : "awful " + tag + " " + i).build());
            theCase(ModerationTargetType.REVIEW, review.getId(), "Spam " + tag, ModerationStatus.OPEN);
        }
        theCase(ModerationTargetType.REVIEW, 987_654_321L, "Spam orphan " + tag, ModerationStatus.OPEN);
        String token = support();

        JsonNode first = page(token, "/admin/reviews/moderation?query=" + tag + "&size=2&page=0");
        assertThat(first.get("totalElements").asLong()).isEqualTo(3);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(2);
        assertThat(total(token, "/admin/reviews/moderation?query=AWFUL " + tag)).as("a review without text is still reachable by the others").isEqualTo(2);
        assertThat(total(token, "/admin/reviews/moderation?query=Critic " + tag)).as("author").isEqualTo(3);
        assertThat(total(token, "/admin/reviews/moderation?query=Rev Studio " + tag)).as("provider").isEqualTo(3);
        assertThat(total(token, "/admin/reviews/moderation?query=Spam " + tag)).as("reason").isEqualTo(3);
    }

    // ── 5. settlements ─────────────────────────────────────────────────────────────────

    private void ledger(ProviderProfile provider, LedgerEntryStatus status) {
        ledgerRepo.save(CommissionLedgerEntry.builder().provider(provider).bookingAmount(new BigDecimal("100"))
                .commissionPercent(new BigDecimal("10")).commissionAmount(new BigDecimal("10")).status(status).build());
    }

    @Test
    void settlementRowsAreSearchedFilteredByStatusAndPagedOnTheServer() throws Exception {
        ProviderProfile late = provider("L " + tag, "Late " + tag, "x", VerificationStatus.APPROVED);
        ProviderProfile within = provider("W " + tag, "Within " + tag, "x", VerificationStatus.APPROVED);
        ProviderProfile paid = provider("P " + tag, "Paid " + tag, "x", VerificationStatus.APPROVED);
        ledger(late, LedgerEntryStatus.OVERDUE); ledger(late, LedgerEntryStatus.DUE);
        ledger(within, LedgerEntryStatus.DUE);
        ledger(paid, LedgerEntryStatus.SETTLED); ledger(paid, LedgerEntryStatus.VOID);
        String finance = login(user(UserRole.ADMIN, "Fin " + tag, Set.of(AdminPermission.FINANCE)));

        JsonNode all = page(finance, "/admin/settlements/providers?query=" + tag + "&size=2&page=0");
        assertThat(all.get("totalElements").asLong()).isEqualTo(3);
        assertThat(all.get("totalPages").asInt()).isEqualTo(2);
        assertThat(all.get("content")).hasSize(2);
        assertThat(total(finance, "/admin/settlements/providers?query=" + tag + "&status=OVERDUE")).isEqualTo(1);
        assertThat(total(finance, "/admin/settlements/providers?query=" + tag + "&status=WITHIN_LIMIT")).isEqualTo(1);
        assertThat(total(finance, "/admin/settlements/providers?query=" + tag + "&status=SETTLED")).isEqualTo(1);
        assertThat(total(finance, "/admin/settlements/providers?query=WITHIN " + tag)).as("provider name, case-insensitive").isEqualTo(1);
        // each row still reports the status the filter selected, and the overdue provider's open balance
        JsonNode overdue = page(finance, "/admin/settlements/providers?query=" + tag + "&status=OVERDUE").get("content").get(0);
        assertThat(overdue.get("status").asText()).isEqualTo("OVERDUE");
        assertThat(overdue.get("providerName").asText()).isEqualTo("Late " + tag);
        assertThat(overdue.get("balanceOwed").asDouble()).isEqualTo(20.0);
        JsonNode settled = page(finance, "/admin/settlements/providers?query=" + tag + "&status=SETTLED").get("content").get(0);
        assertThat(settled.get("status").asText()).isEqualTo("SETTLED");
    }

    @Test
    void settlementsStillNeedFinanceAndRejectUnknownStatuses() throws Exception {
        String support = support();
        mvc.perform(get("/admin/settlements/providers?query=x").header("Authorization", support)).andExpect(status().isForbidden());
        String finance = login(user(UserRole.ADMIN, "Fin2 " + tag, Set.of(AdminPermission.FINANCE)));
        mvc.perform(get("/admin/settlements/providers?status=NOPE").header("Authorization", finance)).andExpect(status().isBadRequest());
    }

    // ── 6. SOS ────────────────────────────────────────────────────────────────────────────

    private SafetyEvent sos(Booking booking, User actor, String notes, boolean resolved) {
        return safetyRepo.save(SafetyEvent.builder().booking(booking).actor(actor).type(SafetyEventType.SOS).notes(notes).resolved(resolved).build());
    }

    @Test
    void sosQueueIsSearchedPagedAndOrderedOnTheServer() throws Exception {
        User customer = user(UserRole.CUSTOMER, "Caller " + tag, Set.of());
        ProviderProfile studio = provider("Sos Owner " + tag, "Sos Studio " + tag, "x", VerificationStatus.APPROVED);
        Booking booking = booking(customer, studio);
        List<SafetyEvent> open = new ArrayList<>();
        for (int i = 0; i < 3; i++) open.add(sos(booking, customer, "help " + tag + " " + i, false));
        sos(booking, customer, "closed " + tag, true);
        String token = support();

        String openBase = "/admin/safety?status=OPEN&query=" + tag;
        JsonNode first = page(token, openBase + "&size=2&page=0");
        assertThat(first.get("totalElements").asLong()).as("the real open count for this search").isEqualTo(3);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(2);
        assertThat(page(token, openBase + "&size=2&page=1").get("content")).hasSize(1);
        // newest first by default, exactly as before
        assertThat(first.get("content").get(0).get("id").asLong()).isEqualTo(open.get(2).getId());
        // the oldest open alert (the one most at risk of being missed) is one cheap read, not a scan of every page
        JsonNode oldest = page(token, openBase + "&order=oldest&size=1");
        assertThat(oldest.get("content")).hasSize(1);
        assertThat(oldest.get("content").get(0).get("id").asLong()).isEqualTo(open.get(0).getId());
        assertThat(oldest.get("totalElements").asLong()).isEqualTo(3);

        assertThat(total(token, "/admin/safety?status=RESOLVED&query=" + tag)).isEqualTo(1);
        assertThat(total(token, "/admin/safety?status=ALL&query=" + tag)).isEqualTo(4);
        assertThat(total(token, "/admin/safety?status=OPEN&query=CALLER " + tag)).as("who raised it, case-insensitive").isEqualTo(3);
        assertThat(total(token, "/admin/safety?status=OPEN&query=Sos Studio " + tag)).as("the provider").isEqualTo(3);
        assertThat(total(token, "/admin/safety?status=OPEN&query=help " + tag + " 1")).as("the note").isEqualTo(1);
        assertThat(total(token, "/admin/safety?status=OPEN&query=" + booking.getId())).as("the booking number").isGreaterThanOrEqualTo(3);
        assertThat(total(token, "/admin/safety?status=OPEN&query=" + tag + " nothing")).isZero();
        // the projection the screen needs is still complete
        JsonNode row = first.get("content").get(0);
        assertThat(row.get("actorName").asText()).isEqualTo("Caller " + tag);
        assertThat(row.get("providerName").asText()).isEqualTo("Sos Studio " + tag);
        assertThat(row.get("bookingId").asLong()).isEqualTo(booking.getId());
        mvc.perform(get("/admin/safety?status=BOGUS").header("Authorization", token)).andExpect(status().isBadRequest());
    }

    @Test
    void theQueuesStillNeedTheirPermission() throws Exception {
        String finance = login(user(UserRole.ADMIN, "NoSupport " + tag, Set.of(AdminPermission.FINANCE)));
        for (String path : List.of("/admin/verification/pending?query=x", "/admin/verification?status=APPROVED&query=x",
                "/admin/moderation?query=x", "/admin/chat/moderation?query=x", "/admin/reviews/moderation?query=x",
                "/admin/safety?query=x")) {
            mvc.perform(get(path).header("Authorization", finance)).andExpect(status().isForbidden());
        }
    }
}
