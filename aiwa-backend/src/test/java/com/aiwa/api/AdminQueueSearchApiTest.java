package com.aiwa.api;

import com.aiwa.support.TestPhones;
import com.aiwa.entity.Booking;
import com.aiwa.entity.Complaint;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.Review;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.BookingStatus;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.enums.PaymentStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ComplaintRepository;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * R4 follow-up (admin queues): the complaint, flag and review queues are paged, filtered and searched ON THE SERVER, and the
 * page carries the real totals, instead of the browser collecting every page up to a cap and filtering what it got.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminQueueSearchApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";
    /** A marker that no other test uses, so the totals below are about these rows only. */
    private final String tag = "qs" + System.nanoTime();

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ServiceRepository serviceRepo;
    @Autowired BookingRepository bookingRepo;
    @Autowired ReviewRepository reviewRepo;
    @Autowired ComplaintRepository complaintRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void reset() { ((InMemoryRedisRuntimeService) redis).clear(); }

    private User user(UserRole role, String name, Set<AdminPermission> perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(name)
                .email("qs-" + role.name().toLowerCase() + n + "@test.aiwa")
                .phone(TestPhones.next())
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms)).build());
    }

    private String login(User u) throws Exception {
        JsonNode d = json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
        return "Bearer " + d.get("accessToken").asText();
    }

    private JsonNode page(String token, String path) throws Exception {
        return json.readTree(mvc.perform(get(path).header("Authorization", token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
    }

    private Complaint complaint(User reporter, String description, ComplaintStatus status, boolean flagged) {
        return complaintRepo.save(Complaint.builder().reporter(reporter).category("BOOKING").description(description)
                .status(status).flagged(flagged).build());
    }

    @Test
    void complaintsArePagedFilteredAndSearchedOnTheServerWithRealTotals() throws Exception {
        User reporter = user(UserRole.CUSTOMER, "Reporter " + tag, Set.of());
        for (int i = 0; i < 5; i++) complaint(reporter, "late arrival " + tag + " #" + i, ComplaintStatus.OPEN, false);
        complaint(reporter, "rude staff " + tag, ComplaintStatus.RESOLVED, false);
        String support = login(user(UserRole.ADMIN, "Support " + tag, Set.of(AdminPermission.SUPPORT)));

        JsonNode first = page(support, "/admin/complaints?query=" + tag + "&size=4&page=0");
        assertThat(first.get("totalElements").asLong()).as("real total, not what one page happens to hold").isEqualTo(6);
        assertThat(first.get("totalPages").asInt()).isEqualTo(2);
        assertThat(first.get("content")).hasSize(4);
        JsonNode second = page(support, "/admin/complaints?query=" + tag + "&size=4&page=1");
        assertThat(second.get("content")).hasSize(2);

        // the status filter and the search combine, and the total follows them
        JsonNode open = page(support, "/admin/complaints?status=OPEN&query=" + tag + "&size=20");
        assertThat(open.get("totalElements").asLong()).isEqualTo(5);
        JsonNode rude = page(support, "/admin/complaints?query=RUDE STAFF " + tag);
        assertThat(rude.get("totalElements").asLong()).as("case-insensitive").isEqualTo(1);
        // the reporter's name is searchable too
        assertThat(page(support, "/admin/complaints?query=Reporter " + tag).get("totalElements").asLong()).isEqualTo(6);
        assertThat(page(support, "/admin/complaints?query=" + tag + "-nothing").get("totalElements").asLong()).isZero();
    }

    @Test
    void aTypedWildcardIsNotAWildcard() throws Exception {
        User reporter = user(UserRole.CUSTOMER, "Wild " + tag, Set.of());
        complaint(reporter, "abc " + tag, ComplaintStatus.OPEN, false);
        String support = login(user(UserRole.ADMIN, "S " + tag, Set.of(AdminPermission.SUPPORT)));
        // "%" and "_" are removed, so "a_c" cannot match "abc" and "%%%" is simply no filter
        assertThat(page(support, "/admin/complaints?query=a_c " + tag).get("totalElements").asLong()).isZero();
    }

    @Test
    void flagsAreSearchedOnTheServerAndOnlyFlaggedComplaintsAppear() throws Exception {
        User reporter = user(UserRole.CUSTOMER, "Flagger " + tag, Set.of());
        complaint(reporter, "unsafe " + tag, ComplaintStatus.OPEN, true);
        complaint(reporter, "unsafe too " + tag, ComplaintStatus.OPEN, true);
        complaint(reporter, "not flagged " + tag, ComplaintStatus.OPEN, false);
        String support = login(user(UserRole.ADMIN, "S2 " + tag, Set.of(AdminPermission.SUPPORT)));
        assertThat(page(support, "/admin/flags?query=" + tag + "&size=1").get("totalElements").asLong()).isEqualTo(2);
        assertThat(page(support, "/admin/flags?query=" + tag + "&size=1").get("content")).hasSize(1);
        assertThat(page(support, "/admin/flags?query=too " + tag).get("totalElements").asLong()).isEqualTo(1);
    }

    @Test
    void reviewsAreSearchedByCommentCustomerAndProviderOnTheServer() throws Exception {
        User owner = user(UserRole.PROVIDER, "Owner " + tag, Set.of());
        User customer = user(UserRole.CUSTOMER, "Reviewer " + tag, Set.of());
        ProviderProfile profile = providerRepo.save(ProviderProfile.builder().user(owner).businessName("Studio " + tag)
                .address("x").primaryCategory(ServiceCategory.HAIR).verificationStatus(VerificationStatus.APPROVED).build());
        com.aiwa.entity.Service svc = serviceRepo.save(com.aiwa.entity.Service.builder().provider(profile).name("Cut")
                .category(ServiceCategory.HAIR).price(new BigDecimal("100")).durationMinutes(30).active(true).build());
        for (int i = 0; i < 3; i++) {
            Booking b = bookingRepo.save(Booking.builder().customer(customer).provider(profile).service(svc)
                    .bookingDate(LocalDate.now().minusDays(i + 1)).startTime(LocalTime.of(10, 0)).endTime(LocalTime.of(10, 30))
                    .status(BookingStatus.COMPLETED).totalPrice(new BigDecimal("100")).paymentStatus(PaymentStatus.CASH_CONFIRMED).build());
            reviewRepo.save(Review.builder().user(customer).provider(profile).booking(b).rating(3 + i % 2)
                    .comment(i == 0 ? null : "great " + tag + " " + i).build());
        }
        String support = login(user(UserRole.ADMIN, "S3 " + tag, Set.of(AdminPermission.SUPPORT)));
        // no search: a review without any comment is still listed (a NULL column must not drop it)
        JsonNode byProvider = page(support, "/admin/reviews?query=Studio " + tag + "&size=2");
        assertThat(byProvider.get("totalElements").asLong()).isEqualTo(3);
        assertThat(byProvider.get("totalPages").asInt()).isEqualTo(2);
        assertThat(page(support, "/admin/reviews?query=great " + tag).get("totalElements").asLong()).isEqualTo(2);
        assertThat(page(support, "/admin/reviews?query=Reviewer " + tag).get("totalElements").asLong()).isEqualTo(3);
        assertThat(page(support, "/admin/reviews").get("totalElements").asLong()).isGreaterThanOrEqualTo(3);
    }

    @Test
    void theQueuesStillNeedSupport() throws Exception {
        String finance = login(user(UserRole.ADMIN, "F " + tag, Set.of(AdminPermission.FINANCE)));
        for (String path : List.of("/admin/complaints?query=x", "/admin/flags?query=x", "/admin/reviews?query=x")) {
            mvc.perform(get(path).header("Authorization", finance)).andExpect(status().isForbidden());
        }
    }
}
