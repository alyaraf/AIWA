package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.Availability;
import com.aiwa.entity.Booking;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.StaffMember;
import com.aiwa.entity.User;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.AvailabilityRepository;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.ServiceRepository;
import com.aiwa.repository.StaffMemberRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.util.AiwaTime;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.math.BigDecimal;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CR-13 (a)–(e): the booking rule gaps left after the fix pass, through the
 * real HTTP stack. (f), the daylight-saving nights, is in BookingDstNightTest.
 */
@SpringBootTest(properties = "aiwa.booking.auto-dedup-window=3s")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BookingRuleGapsApiTest {

    /** The in-memory Redis, which can also be switched off and remembers the TTL of each write. */
    static class TestRedis extends InMemoryRedisRuntimeService {
        final AtomicBoolean down = new AtomicBoolean();
        final Map<String, Duration> ttls = new ConcurrentHashMap<>();

        @Override
        public void set(String key, String value, Duration ttl) {
            ttls.put(key + "=" + value, ttl);
            super.set(key, value, ttl);
        }

        @Override
        public synchronized boolean setIfAbsent(String key, String value, Duration ttl) {
            if (down.get()) throw new IllegalStateException("Redis is down");
            return super.setIfAbsent(key, value, ttl);
        }
    }

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new TestRedis();
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
    @Autowired StaffMemberRepository staffRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @Autowired JdbcTemplate jdbc;
    @SpyBean BookingRepository bookingRepo;

    private User customerUser;
    private String customer;
    private String provider;
    private ProviderProfile profile;
    private com.aiwa.entity.Service service;

    private User user(UserRole role) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role.name().toLowerCase() + " " + n)
                .email("gaps-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone(TestPhones.next())
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true).build());
    }

    private String login(User u) throws Exception {
        return "Bearer " + data(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk())).get("accessToken").asText();
    }

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    /** An approved provider open all day, every day, with one 60-minute service. */
    @BeforeEach
    void aProviderAndACustomer() throws Exception {
        TestRedis r = (TestRedis) redis;
        r.clear();
        r.down.set(false);
        r.ttls.clear();
        User owner = user(UserRole.PROVIDER);
        profile = providerRepo.save(ProviderProfile.builder()
                .user(owner).businessName("Studio " + owner.getId()).address("Zamalek, Cairo")
                .latitude(30.06).longitude(31.22).primaryCategory(ServiceCategory.HAIR)
                .verificationStatus(VerificationStatus.APPROVED).travelBufferMinutes(0).build());
        service = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(profile).name("Haircut").category(ServiceCategory.HAIR)
                .price(new BigDecimal("300")).durationMinutes(60).active(true).build());
        for (DayOfWeek d : DayOfWeek.values()) {
            availabilityRepo.save(Availability.builder().provider(profile).dayOfWeek(d)
                    .startTime(LocalTime.MIN).endTime(LocalTime.of(23, 59))
                    .slotDurationMinutes(30).available(true).build());
        }
        customerUser = user(UserRole.CUSTOMER);
        customer = login(customerUser);
        provider = login(owner);
    }

    private Map<String, Object> scheduled(LocalDate date, String time) {
        Map<String, Object> body = new HashMap<>(Map.of(
                "providerId", profile.getId(), "serviceId", service.getId(), "bookingType", "SCHEDULED",
                "bookingDate", date.toString(), "startTime", time, "homeService", false));
        return body;
    }

    private ResultActions book(Map<String, Object> body, String idempotencyKey) throws Exception {
        var req = post("/bookings").header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        if (idempotencyKey != null) req.header("Idempotency-Key", idempotencyKey);
        return mvc.perform(req);
    }

    private long booked(Map<String, Object> body) throws Exception {
        return data(book(body, null).andExpect(status().isCreated())).get("id").asLong();
    }

    private ResultActions reschedule(long id, LocalDate date, String time) throws Exception {
        return mvc.perform(patch("/bookings/" + id + "/reschedule").header("Authorization", customer)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("bookingDate", date.toString(), "startTime", time))));
    }

    // ── (a) de-dup without an Idempotency-Key ─────────────────────────────────

    @Test
    void rebookingRightAfterACancelCreatesANewLiveBooking() throws Exception {
        Map<String, Object> body = scheduled(AiwaTime.today().plusDays(2), "10:00");
        long first = booked(body);
        mvc.perform(patch("/bookings/" + first + "/cancel").header("Authorization", customer))
                .andExpect(status().isOk());

        // The same request again, seconds later: used to answer 201 with the cancelled booking.
        JsonNode again = data(book(body, null).andExpect(status().isCreated()));

        assertThat(again.get("id").asLong()).isNotEqualTo(first);
        assertThat(again.get("status").asText()).isEqualTo("PENDING");
    }

    @Test
    void theDedupEntryIsKeptForTheConfiguredWindow() throws Exception {
        long id = booked(scheduled(AiwaTime.today().plusDays(2), "12:00"));

        Map<String, Duration> ttls = ((TestRedis) redis).ttls;
        String entry = ttls.keySet().stream()
                .filter(k -> k.startsWith("idem:booking:" + customerUser.getId() + ":auto:") && k.endsWith("=" + id))
                .findFirst().orElseThrow();
        // aiwa.booking.auto-dedup-window (3s in this test); it used to be 5 minutes.
        assertThat(ttls.get(entry)).isEqualTo(Duration.ofSeconds(3));
    }

    // ── (b) maximum service duration ──────────────────────────────────────────

    private ResultActions addService(int minutes) throws Exception {
        return mvc.perform(post("/provider/services").header("Authorization", provider)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("name", "Long " + minutes, "price", 500,
                        "durationMinutes", minutes, "category", "HAIR"))));
    }

    @Test
    void aServiceLongerThanTheMaximumIsRefused() throws Exception {
        addService(481).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Duration must be at most 480 minutes"));
        // 24 hours wrapped the stored end time and hid the booking from the overlap check.
        addService(1440).andExpect(status().isBadRequest());
        addService(480).andExpect(status().isCreated());
    }

    // ── (c) provider accept ───────────────────────────────────────────────────

    private Booking stored(long id) {
        return bookingRepo.findById(id).orElseThrow();
    }

    @Test
    void acceptingABookingWhoseStartHasPassedIsRefused() throws Exception {
        long id = booked(scheduled(AiwaTime.today().plusDays(2), "10:00"));
        Booking b = stored(id);
        LocalDateTime anHourAgo = AiwaTime.now().minusMinutes(60).withSecond(0).withNano(0);
        b.setBookingDate(anHourAgo.toLocalDate());
        b.setStartTime(anHourAgo.toLocalTime());
        b.setEndTime(anHourAgo.toLocalTime().plusMinutes(60));
        bookingRepo.save(b);

        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", provider))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.start_passed"));
        assertThat(stored(id).getStatus()).isEqualTo(BookingStatus.PENDING);
    }

    @Test
    void acceptingTheOriginalTimeClearsThePendingProposal() throws Exception {
        long id = booked(scheduled(AiwaTime.today().plusDays(2), "10:00"));
        mvc.perform(patch("/bookings/" + id + "/propose-time").header("Authorization", provider)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "bookingDate", AiwaTime.today().plusDays(3).toString(), "startTime", "15:00"))))
                .andExpect(status().isOk());

        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", provider))
                .andExpect(status().isOk());

        Booking b = stored(id);
        assertThat(b.getStatus()).isEqualTo(BookingStatus.ACCEPTED);
        assertThat(b.getProposedDate()).isNull();
        assertThat(b.getProposedStartTime()).isNull();
        assertThat(b.getProposedAt()).isNull();
    }

    @Test
    void acceptingForAStaffMemberWhoLeftIsRefused() throws Exception {
        StaffMember staff = staffRepo.save(StaffMember.builder().provider(profile).fullName("Mona").build());
        Map<String, Object> body = scheduled(AiwaTime.today().plusDays(2), "10:00");
        body.put("staffMemberId", staff.getId());
        long id = booked(body);
        staff.setActive(false);
        staffRepo.save(staff);

        mvc.perform(patch("/bookings/" + id + "/accept").header("Authorization", provider))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.staff_unavailable"));
    }

    // ── (d) reschedule ────────────────────────────────────────────────────────

    @Test
    void reschedulingWithAStaffMemberWhoLeftIsRefused() throws Exception {
        StaffMember staff = staffRepo.save(StaffMember.builder().provider(profile).fullName("Mona").build());
        Map<String, Object> body = scheduled(AiwaTime.today().plusDays(2), "10:00");
        body.put("staffMemberId", staff.getId());
        long id = booked(body);
        staff.setActive(false);
        staffRepo.save(staff);

        reschedule(id, AiwaTime.today().plusDays(3), "11:00")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("booking.error.staff_unavailable"));
        assertThat(stored(id).getStartTime()).isEqualTo(LocalTime.of(10, 0));
    }

    @Test
    void reschedulingAServiceThatIsNoLongerOfferedIsRefused() throws Exception {
        long id = booked(scheduled(AiwaTime.today().plusDays(2), "10:00"));
        service.setActive(false);
        serviceRepo.save(service);

        reschedule(id, AiwaTime.today().plusDays(3), "11:00")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("service.inactive"));
        assertThat(stored(id).getStartTime()).isEqualTo(LocalTime.of(10, 0));
    }

    // ── (e) a retried Book Now that reaches the unique index ──────────────────

    @Test
    void aRetriedBookNowThatHitsTheUniqueIndexReturnsTheOriginalBooking() throws Exception {
        assumeTrue(AiwaTime.timeNow().isBefore(LocalTime.of(22, 45)), "needs two free Book Now slots today");
        com.aiwa.entity.Service quick = serviceRepo.save(com.aiwa.entity.Service.builder()
                .provider(profile).name("Fringe trim").category(ServiceCategory.HAIR)
                .price(new BigDecimal("50")).durationMinutes(5).active(true).build());
        // The index production has (V17); the test schema is generated from the entities.
        jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_bookings_customer_idem ON bookings (customer_id, idempotency_key)");
        ((TestRedis) redis).down.set(true);
        Map<String, Object> bookNow = Map.of("providerId", profile.getId(), "serviceId", quick.getId(),
                "bookingType", "BOOK_NOW", "homeService", false);
        long original = data(book(bookNow, "tap-1").andExpect(status().isCreated())).get("id").asLong();

        // The retry arrives while the first request is still in flight: its look-up
        // by key finds nothing yet, so it goes on to insert a second row.
        AtomicBoolean inFlight = new AtomicBoolean(true);
        doAnswer(inv -> inFlight.getAndSet(false)
                ? Optional.empty()
                : bookingRepo.findAll().stream()
                        .filter(b -> "tap-1".equals(b.getIdempotencyKey())).findFirst())
                .when(bookingRepo).findByCustomerIdAndIdempotencyKey(any(), any());

        book(bookNow, "tap-1").andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.id").value(original));
        assertThat(inFlight).isFalse();
        assertThat(bookingRepo.findAll().stream().filter(b -> "tap-1".equals(b.getIdempotencyKey()))).hasSize(1);
    }
}
