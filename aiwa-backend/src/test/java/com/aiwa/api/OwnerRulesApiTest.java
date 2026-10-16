package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.Availability;
import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.TermsPolicy;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.CommissionLedgerRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.TermsPolicyRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.BookingServiceImpl;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The product rules the owner chose on 2026-10-04: SOS after a cancellation, locked travel
 * fees, deletion refused with live work, customers-only booking, the cancellation penalty,
 * stale-booking closure, no-show contests, rounded home locations and terms on booking.
 */
@SpringBootTest(properties = "aiwa.terms.enforce-on-booking=true")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class OwnerRulesApiTest {

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
    @Autowired CommissionLedgerRepository ledgerRepo;
    @Autowired TermsPolicyRepository termsRepo;
    @Autowired BookingServiceImpl bookingService;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @Autowired com.aiwa.repository.ModerationCaseRepository moderationRepo;
    @Autowired com.aiwa.repository.NotificationRepository notificationRepo;
    @Autowired com.aiwa.repository.AuditLogRepository auditRepo;
    @Autowired com.aiwa.repository.ProviderWaitlistRepository waitlistRepo;

    private User owner;
    private ProviderProfile profile;
    private com.aiwa.entity.Service service;
    private User customer;
    private String customerToken;
    private String providerToken;

    private User user(UserRole role) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("rules-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone(TestPhones.next())
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true).build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("data").get("accessToken").asText();
    }

    @BeforeEach
    void anApprovedProviderAndACustomer() throws Exception {
        ((InMemoryRedisRuntimeService) redis).clear();
        owner = user(UserRole.PROVIDER);
        profile = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("12 Nile St, Zamalek")
                .latitude(30.0612).longitude(31.2234).primaryCategory(ServiceCategory.HAIR)
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
        // SA-15: V13 seeds live terms on PostgreSQL (the H2 schema has none), and this class turns the
        // booking check on, so a customer who is meant to book has accepted them. The tests that
        // are about missing acceptance publish their own version and keep their own checks.
        var live = termsRepo.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc("CUSTOMER_TERMS").orElse(null);
        if (live != null) {
            mvc.perform(post("/terms/accept").param("version", live.getVersion()).param("type", "CUSTOMER_TERMS")
                    .header("Authorization", customerToken)).andExpect(status().isOk());
        }
    }

    private long book(boolean home, Long addressId) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>(Map.of(
                "providerId", profile.getId(), "serviceId", service.getId(), "bookingType", "SCHEDULED",
                "bookingDate", AiwaTime.today().plusDays(3).toString(), "startTime", "10:00", "homeService", home));
        if (addressId != null) body.put("savedAddressId", addressId);
        return json.readTree(mvc.perform(post("/bookings").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
    }

    private Booking booking(long id) {
        return bookingRepo.findById(id).orElseThrow();
    }

    private void set(long id, java.util.function.Consumer<Booking> change) {
        Booking b = booking(id);
        change.accept(b);
        bookingRepo.save(b);
    }

    private void accept(long id) throws Exception {
        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", providerToken)).andExpect(status().isOk());
    }

    // ── CR-09: SOS ─────────────────────────────────────────────────────────────

    @Test
    void anSosIsAllowedShortlyAfterACancellation() throws Exception {
        long id = book(false, null);
        accept(id);
        set(id, b -> { b.setStatus(BookingStatus.CANCELLED); b.setCancelledAt(LocalDateTime.now().minusMinutes(30)); });
        mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"type\":\"SOS\"}"))
                .andExpect(status().isCreated());
        set(id, b -> b.setCancelledAt(LocalDateTime.now().minusHours(7)));
        mvc.perform(post("/bookings/" + id + "/safety").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"type\":\"SOS\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("safety.error.sos_not_live"));
    }

    // ── AU-05: customers book ──────────────────────────────────────────────────

    @Test
    void onlyCustomerAccountsCanCreateBookings() throws Exception {
        mvc.perform(post("/bookings").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", profile.getId(), "serviceId", service.getId(),
                                "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(3).toString(),
                                "startTime", "10:00", "homeService", false))))
                .andExpect(status().isForbidden());
    }

    // ── CR-10: deletion ────────────────────────────────────────────────────────

    @Test
    void anAccountWithALiveBookingCannotBeClosed() throws Exception {
        long id = book(false, null);
        accept(id);
        mvc.perform(delete("/account").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("currentPassword", PASSWORD))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("account.error.delete_live_bookings"));
        assertThat(userRepo.findById(customer.getId()).orElseThrow().isActive()).isTrue();
    }

    // ── CR-12: travel fee ──────────────────────────────────────────────────────

    @Test
    void aTravelQuoteIsAcceptedOnlyWithTheAmountSeenAndNeverRequotedAfterAcceptance() throws Exception {
        long addressId = json.readTree(mvc.perform(post("/account/addresses").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"label\":\"Home\",\"addressLine\":\"3 Nile St\",\"latitude\":30.06,\"longitude\":31.22}"))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
        long id = book(true, addressId);
        mvc.perform(patch("/bookings/" + id + "/travel-fee-quote").param("amount", "100")
                .header("Authorization", providerToken)).andExpect(status().isOk());

        mvc.perform(patch("/bookings/" + id + "/travel-fee-response").param("accept", "true")
                        .header("Authorization", customerToken))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("booking.error.quote_changed"));
        mvc.perform(patch("/bookings/" + id + "/travel-fee-response").param("accept", "true").param("amount", "150")
                        .header("Authorization", customerToken))
                .andExpect(status().isConflict());
        mvc.perform(patch("/bookings/" + id + "/travel-fee-response").param("accept", "true").param("amount", "100")
                        .header("Authorization", customerToken))
                .andExpect(status().isOk());

        accept(id);
        mvc.perform(patch("/bookings/" + id + "/travel-fee-quote").param("amount", "400")
                        .header("Authorization", providerToken))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("booking.error.quote_locked"));
    }

    // ── AU-07: penalty and strikes ─────────────────────────────────────────────

    @Test
    void aProviderWhoCancelsAnAcceptedBookingIsChargedThePenalty() throws Exception {
        profile.setProviderCancelPenaltyPercentOverride(new BigDecimal("20"));
        providerRepo.save(profile);
        long id = book(false, null);
        accept(id);
        mvc.perform(patch("/bookings/" + id + "/cancel").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Sick\"}"))
                .andExpect(status().isOk());
        var entry = ledgerRepo.findByBookingId(id).orElseThrow();
        assertThat(entry.getCommissionAmount()).isEqualByComparingTo("60.00"); // 20% of 300
        assertThat(booking(id).isPenaltyApplied()).isTrue();
    }

    @Test
    void threePenalisedCancellationsPauseNewBookings() throws Exception {
        for (int i = 0; i < 3; i++) {
            long id = json.readTree(mvc.perform(post("/bookings").header("Authorization", customerToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(Map.of("providerId", profile.getId(), "serviceId", service.getId(),
                                    "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(3 + i).toString(),
                                    "startTime", "10:00", "homeService", false))))
                    .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                    .get("data").get("id").asLong();
            accept(id);
            mvc.perform(patch("/bookings/" + id + "/cancel").header("Authorization", providerToken)
                            .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Sick\"}"))
                    .andExpect(status().isOk());
        }
        var paused = providerRepo.findById(profile.getId()).orElseThrow();
        // SA-08: a disciplinary hold of its own, so settling the penalties cannot lift it.
        assertThat(paused.isDisciplinaryHold()).isTrue();
        assertThat(paused.isSettlementPaused()).isFalse();
        assertThat(paused.isBookingPaused()).isTrue();
    }

    // ── AU-03: stale bookings and no-show contests ─────────────────────────────

    @Test
    void aVisitStillInProgressADayAfterItsSlotIsCompletedWithCommission() throws Exception {
        long id = book(false, null);
        set(id, b -> {
            b.setStatus(BookingStatus.IN_PROGRESS);
            b.setBookingDate(LocalDate.now().minusDays(3));
        });
        bookingService.closeStaleBookings();
        Booking b = booking(id);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.COMPLETED);
        assertThat(b.getPaymentStatus()).isEqualTo(PaymentStatus.CASH_PENDING);
        assertThat(ledgerRepo.findByBookingId(id)).isPresent();
    }

    @Test
    void anAcceptedBookingADayPastItsSlotIsFlaggedOnceNotChanged() throws Exception {
        long id = book(false, null);
        accept(id);
        set(id, b -> b.setBookingDate(LocalDate.now().minusDays(3)));
        bookingService.closeStaleBookings();
        assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.ACCEPTED);
        assertThat(booking(id).getClosureFlaggedAt()).isNotNull();
        assertThat(bookingService.closeStaleBookings()).as("flagged once").isZero();
    }

    @Test
    void aNoShowCanBeContestedOnceAndFinanceCanOverturnIt() throws Exception {
        long id = book(false, null);
        set(id, b -> {
            b.setStatus(BookingStatus.NO_SHOW);
            b.setBookingDate(LocalDate.now().minusDays(1));
        });
        mvc.perform(patch("/bookings/" + id + "/contest-no-show").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"I was there\"}"))
                .andExpect(status().isOk());
        assertThat(booking(id).getPaymentStatus()).isEqualTo(PaymentStatus.DISPUTED);
        mvc.perform(patch("/bookings/" + id + "/contest-no-show").header("Authorization", customerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.no_show_already_contested"));

        bookingService.adminResolveDispute(id, "PAID");
        assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.COMPLETED);
        assertThat(ledgerRepo.findByBookingId(id)).isPresent();
    }

    @Test
    void aNoShowCannotBeContestedAfterTheWindowOrByAnotherUser() throws Exception {
        long id = book(false, null);
        set(id, b -> { b.setStatus(BookingStatus.NO_SHOW); b.setBookingDate(LocalDate.now().minusDays(5)); });
        mvc.perform(patch("/bookings/" + id + "/contest-no-show").header("Authorization", customerToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.no_show_contest_closed"));
        mvc.perform(patch("/bookings/" + id + "/contest-no-show").header("Authorization", providerToken))
                .andExpect(status().isForbidden());
    }

    // ── AU-18: public location ─────────────────────────────────────────────────

    @Test
    void anAnonymousVisitorSeesARoundedPinAndNoAddressForAHomeBasedProvider() throws Exception {
        mvc.perform(get("/providers/" + profile.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.latitude").value(30.06))
                .andExpect(jsonPath("$.data.longitude").value(31.225))
                .andExpect(jsonPath("$.data.address").doesNotExist());
        // The owner and a customer with an accepted booking still see the exact place.
        mvc.perform(get("/providers/" + profile.getId()).header("Authorization", providerToken))
                .andExpect(jsonPath("$.data.latitude").value(30.0612))
                .andExpect(jsonPath("$.data.address").value("12 Nile St, Zamalek"));
        long id = book(false, null);
        accept(id);
        mvc.perform(get("/providers/" + profile.getId()).header("Authorization", customerToken))
                .andExpect(jsonPath("$.data.latitude").value(30.0612));
    }

    @Test
    void aShopKeepsItsExactLocation() throws Exception {
        profile.setProviderType(com.aiwa.enums.ProviderType.SHOP);
        providerRepo.save(profile);
        mvc.perform(get("/providers/" + profile.getId()))
                .andExpect(jsonPath("$.data.latitude").value(30.0612))
                .andExpect(jsonPath("$.data.address").exists());
    }

    // ── AU-19: terms ───────────────────────────────────────────────────────────

    @Test
    void aBookingNeedsTheLiveCustomerTermsAndAcceptingOneDocumentDoesNotCoverAnother() throws Exception {
        termsRepo.save(TermsPolicy.builder().type("CUSTOMER_TERMS").version("9.0").contentEn("x").contentAr("x")
                .publishedBy("test").active(true).build());
        try {
            mvc.perform(post("/bookings").header("Authorization", customerToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json.writeValueAsString(Map.of("providerId", profile.getId(), "serviceId", service.getId(),
                                    "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(3).toString(),
                                    "startTime", "10:00", "homeService", false))))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("terms.error.not_accepted"));
            mvc.perform(get("/auth/me").header("Authorization", customerToken))
                    .andExpect(jsonPath("$.data.termsUpToDate").value(false));

            // Another document type does not count.
            termsRepo.save(TermsPolicy.builder().type("PRIVACY").version("9.0").contentEn("x").contentAr("x")
                    .publishedBy("test").active(true).build());
            mvc.perform(post("/terms/accept").param("version", "9.0").param("type", "PRIVACY")
                    .header("Authorization", customerToken)).andExpect(status().isOk());
            mvc.perform(get("/auth/me").header("Authorization", customerToken))
                    .andExpect(jsonPath("$.data.termsUpToDate").value(false));

            mvc.perform(post("/terms/accept").param("version", "9.0").param("type", "CUSTOMER_TERMS")
                    .header("Authorization", customerToken)).andExpect(status().isOk());
            mvc.perform(get("/auth/me").header("Authorization", customerToken))
                    .andExpect(jsonPath("$.data.termsUpToDate").value(true));
            book(false, null);
        } finally {
            termsRepo.findAll().stream().filter(p -> "9.0".equals(p.getVersion())).forEach(termsRepo::delete);
        }
    }

    // ── System audit 2026-10-04 ────────────────────────────────────────────────

    private String superAdminToken() throws Exception {
        int n = SEQ.incrementAndGet();
        User admin = userRepo.save(User.builder().fullName("sa admin " + n).email("sa-admin" + n + "@test.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD))
                .role(UserRole.ADMIN).active(true).termsAccepted(true)
                .adminPermissions(new java.util.HashSet<>(java.util.EnumSet.of(
                        com.aiwa.enums.AdminPermission.SUPER_ADMIN, com.aiwa.enums.AdminPermission.SUPPORT)))
                .build());
        return login(admin);
    }

    // SA-07: a rate change applies to bookings made after it, as the admin panel says.
    @Test
    void aCommissionRateChangeDoesNotReachBookingsAlreadyMade() throws Exception {
        profile.setCommissionOverridePercent(new BigDecimal("10"));
        providerRepo.save(profile);
        long id = book(false, null);
        assertThat(booking(id).getCommissionPercentAtBooking()).isEqualByComparingTo("10");

        profile = providerRepo.findById(profile.getId()).orElseThrow(); // the booking bumped its version
        profile.setCommissionOverridePercent(new BigDecimal("25"));
        providerRepo.save(profile);
        set(id, b -> {
            b.setStatus(BookingStatus.IN_PROGRESS);
            b.setBookingDate(LocalDate.now().minusDays(3));
        });
        bookingService.closeStaleBookings();

        var entry = ledgerRepo.findByBookingId(id).orElseThrow();
        assertThat(entry.getCommissionPercent()).isEqualByComparingTo("10");
        assertThat(entry.getCommissionAmount()).isEqualByComparingTo("30.00"); // 10% of 300, not 25%
    }

    // SA-09: a resolver only acts on a case of its own type.
    @Test
    void aModerationResolverRefusesACaseOfAnotherType() throws Exception {
        String admin = superAdminToken();
        var reviewCase = moderationRepo.save(com.aiwa.entity.ModerationCase.builder()
                .targetType(com.aiwa.enums.ModerationTargetType.REVIEW).targetId(987654L).reason("x").build());
        var chatCase = moderationRepo.save(com.aiwa.entity.ModerationCase.builder()
                .targetType(com.aiwa.enums.ModerationTargetType.CHAT_MESSAGE).targetId(987655L).reason("x").build());

        mvc.perform(post("/admin/chat/moderation/" + reviewCase.getId() + "/resolve").param("action", "REMOVE")
                        .header("Authorization", admin))
                .andExpect(status().isNotFound());
        mvc.perform(post("/admin/reviews/moderation/" + chatCase.getId() + "/resolve").param("action", "REMOVE")
                        .header("Authorization", admin))
                .andExpect(status().isNotFound());
        assertThat(moderationRepo.findById(reviewCase.getId()).orElseThrow().getStatus())
                .isEqualTo(com.aiwa.enums.ModerationStatus.OPEN);
        assertThat(moderationRepo.findById(chatCase.getId()).orElseThrow().getStatus())
                .isEqualTo(com.aiwa.enums.ModerationStatus.OPEN);
    }

    // SA-11: support's deletion does not cancel around a visit that is already under way.
    @Test
    void anAdminCannotDeleteAnAccountWhileAVisitIsOnTheWay() throws Exception {
        long id = book(false, null);
        set(id, b -> b.setStatus(BookingStatus.ON_THE_WAY));
        mvc.perform(delete("/admin/users/" + customer.getId()).header("Authorization", superAdminToken()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("admin.error.delete_live_visit"));
        assertThat(userRepo.findById(customer.getId()).orElseThrow().isActive()).isTrue();
        assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.ON_THE_WAY);
    }

    private String supportAdminToken() throws Exception {
        int n = SEQ.incrementAndGet();
        User admin = userRepo.save(User.builder().fullName("support admin " + n).email("support-admin" + n + "@test.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD))
                .role(UserRole.ADMIN).active(true).termsAccepted(true)
                .adminPermissions(new java.util.HashSet<>(java.util.EnumSet.of(com.aiwa.enums.AdminPermission.SUPPORT)))
                .build());
        return login(admin);
    }

    private long bookOn(int daysAhead) throws Exception {
        return json.readTree(mvc.perform(post("/bookings").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("providerId", profile.getId(), "serviceId", service.getId(),
                                "bookingType", "SCHEDULED", "bookingDate", AiwaTime.today().plusDays(daysAhead).toString(),
                                "startTime", "10:00", "homeService", false))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
    }

    // AQ-01: suspending a customer left their bookings live; the provider could still accept, and backing out of an
    // accepted one cost a strike and the cancellation penalty.
    @Test
    void suspendingACustomerCancelsTheirUpcomingBookingsAndTellsTheProviderWithoutPenalty() throws Exception {
        long accepted = bookOn(3);
        accept(accepted);
        long pending = bookOn(4);

        mvc.perform(patch("/admin/users/" + customer.getId() + "/deactivate").header("Authorization", supportAdminToken()))
                .andExpect(status().isOk());

        for (long id : new long[]{accepted, pending}) {
            assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.CANCELLED);
            assertThat(booking(id).getCancelledBy()).isEqualTo("ADMIN");
            assertThat(booking(id).isPenaltyApplied()).isFalse();
            assertThat(ledgerRepo.findByBookingId(id)).isEmpty();
        }
        assertThat(notificationRepo.findByUserIdOrderByCreatedAtDesc(owner.getId(), org.springframework.data.domain.PageRequest.of(0, 50))
                .stream().filter(n -> n.getType() == com.aiwa.enums.NotificationType.BOOKING_CANCELLED).count()).isEqualTo(2);
        assertThat(providerRepo.findById(profile.getId()).orElseThrow().getCancellationStrikes()).isZero();
    }

    @Test
    void aCustomerCannotBeSuspendedWhileAVisitIsOnTheWay() throws Exception {
        long id = book(false, null);
        set(id, b -> b.setStatus(BookingStatus.ON_THE_WAY));
        mvc.perform(patch("/admin/users/" + customer.getId() + "/deactivate").header("Authorization", supportAdminToken()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("admin.error.delete_live_visit"));
        assertThat(userRepo.findById(customer.getId()).orElseThrow().isActive()).isTrue();
        assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.ON_THE_WAY);
    }

    // AQ-02: deletion left the user's sign-in email as the actor of their audit rows, their name in support's
    // USER_DELETED row, and their waitlist entry with where they searched from.
    @Test
    void deletingAnAccountLeavesNoEmailInTheAuditLogAndNoWaitlistEntry() throws Exception {
        long id = book(false, null); // pending: the account can still be closed
        long messageId = json.readTree(mvc.perform(post("/bookings/" + id + "/chat").header("Authorization", providerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"message\":\"hello\"}"))
                .andExpect(status().is2xxSuccessful()).andReturn().getResponse().getContentAsString())
                .get("data").get("id").asLong();
        mvc.perform(post("/bookings/" + id + "/chat/" + messageId + "/report").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"rude\"}"))
                .andExpect(status().isCreated());
        mvc.perform(post("/providers/waitlist").param("category", "HAIR").param("lat", "30.06").param("lng", "31.22")
                .header("Authorization", customerToken)).andExpect(status().isOk());
        String email = customer.getEmail();
        // A row written before AQ-02, when the actor was the sign-in identifier.
        auditRepo.save(com.aiwa.entity.AuditLogEntry.builder().actor(email).action("SOS_RAISED").target("booking #" + id).build());

        mvc.perform(delete("/account").header("Authorization", customerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("currentPassword", PASSWORD))))
                .andExpect(status().isOk());

        var audit = auditRepo.findAll();
        assertThat(audit).noneMatch(a -> a.getActor().equalsIgnoreCase(email)
                || (a.getTarget() != null && a.getTarget().contains(email)));
        assertThat(audit).anyMatch(a -> "CHAT_MESSAGE_REPORTED".equals(a.getAction())
                && a.getActor().equals("user #" + customer.getId()));
        assertThat(waitlistRepo.findAll()).noneMatch(w -> w.getUser().getId().equals(customer.getId()));
    }

    @Test
    void supportsDeletionLogsTheAccountByIdNotByName() throws Exception {
        mvc.perform(delete("/admin/users/" + customer.getId()).header("Authorization", superAdminToken()))
                .andExpect(status().isOk());
        assertThat(auditRepo.findAll().stream().filter(a -> "USER_DELETED".equals(a.getAction()))
                .map(com.aiwa.entity.AuditLogEntry::getTarget))
                .contains("user #" + customer.getId())
                .noneMatch(t -> t.contains(customer.getFullName() + " "));
    }

    // AQ-03: request-info and reject took an approved provider off the listing while its accepted bookings stayed live.
    @Test
    void anApprovedProviderCannotBeRejectedOrAskedForMoreInformation() throws Exception {
        long id = book(false, null);
        accept(id);
        String support = supportAdminToken();
        mvc.perform(post("/admin/verification/" + profile.getId() + "/request-info").header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"message\":\"Re-upload your ID\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("verification.error.not_under_review"));
        mvc.perform(post("/admin/verification/" + profile.getId() + "/reject").header("Authorization", support)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"reason\":\"Blurry ID\"}"))
                .andExpect(status().isConflict());

        ProviderProfile after = providerRepo.findById(profile.getId()).orElseThrow();
        assertThat(after.getVerificationStatus()).isEqualTo(VerificationStatus.APPROVED);
        assertThat(after.getRejectionReason()).isNull();
        assertThat(booking(id).getStatus()).isEqualTo(BookingStatus.ACCEPTED);
    }

    @Test
    void publishingCustomerTermsNotifiesCustomersOnly() throws Exception {
        User boss = userRepo.save(User.builder().fullName("boss").email("rules-boss" + SEQ.incrementAndGet() + "@test.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD)).role(UserRole.ADMIN).active(true)
                .termsAccepted(true).adminPermissions(new java.util.HashSet<>(java.util.Set.of(
                        com.aiwa.enums.AdminPermission.SUPER_ADMIN))).build());
        String version = "notify-" + SEQ.incrementAndGet();
        try {
            mvc.perform(post("/terms").header("Authorization", login(boss))
                            .param("version", version).param("type", "CUSTOMER_TERMS").param("contentEn", "New terms"))
                    .andExpect(status().isCreated());

            // The fan-out runs on the push pool after commit.
            long deadline = System.currentTimeMillis() + 10_000;
            while (termsNotices(customer) == 0 && System.currentTimeMillis() < deadline) Thread.sleep(50);
            assertThat(termsNotices(customer)).isEqualTo(1);
            assertThat(termsNotices(owner)).isZero();
            assertThat(termsNotices(boss)).isZero();
        } finally {
            termsRepo.findByTypeAndVersion("CUSTOMER_TERMS", version).ifPresent(termsRepo::delete);
        }
    }

    private long termsNotices(User u) {
        return notificationRepo.findByUserIdOrderByCreatedAtDesc(u.getId(), org.springframework.data.domain.PageRequest.of(0, 50))
                .stream().filter(n -> n.getType() == com.aiwa.enums.NotificationType.TERMS_UPDATED).count();
    }
}
