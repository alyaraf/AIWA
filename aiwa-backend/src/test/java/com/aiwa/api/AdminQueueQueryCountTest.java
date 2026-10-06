package com.aiwa.api;

import com.aiwa.entity.Complaint;
import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.ComplaintStatus;
import com.aiwa.enums.ServiceCategory;
import com.aiwa.enums.UserRole;
import com.aiwa.enums.VerificationStatus;
import com.aiwa.repository.ComplaintRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
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

import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Performance evidence (R4 follow-up): the cost of an admin queue page must not grow with the number of rows on it.
 * The number of SQL statements is measured with Hibernate statistics for a page of 3 rows and a page of 20 rows, each
 * row with its OWN reporter, target user and target provider (the worst case for lazy loading); the two counts must be
 * equal, i.e. there is no per-row query (N+1). This is a statement count on H2, not a latency or PostgreSQL plan measurement.
 */
@SpringBootTest(properties = {"spring.jpa.properties.hibernate.generate_statistics=true"})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminQueueQueryCountTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";
    private final String tag = "qc" + System.nanoTime();

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired ProviderProfileRepository providerRepo;
    @Autowired ComplaintRepository complaintRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @Autowired EntityManagerFactory emf;

    @BeforeEach
    void reset() { ((InMemoryRedisRuntimeService) redis).clear(); }

    private User user(UserRole role, Set<AdminPermission> perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName(role + " " + n + " " + tag)
                .email("qc-" + role.name().toLowerCase() + n + "@test.aiwa").phone("+2010774" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms)).build());
    }

    private void complaints(int count) {
        for (int i = 0; i < count; i++) {
            User reporter = user(UserRole.CUSTOMER, Set.of());
            User target = user(UserRole.CUSTOMER, Set.of());
            User owner = user(UserRole.PROVIDER, Set.of());
            ProviderProfile provider = providerRepo.save(ProviderProfile.builder().user(owner).businessName("P " + tag + " " + i)
                    .address("x").primaryCategory(ServiceCategory.HAIR).verificationStatus(VerificationStatus.APPROVED).build());
            complaintRepo.save(Complaint.builder().reporter(reporter).targetUser(target).targetProvider(provider)
                    .category("BOOKING").description("row " + tag + " " + i).status(ComplaintStatus.OPEN).flagged(i % 2 == 0).build());
        }
    }

    private long statementsFor(String token, String path) throws Exception {
        Statistics stats = emf.unwrap(SessionFactory.class).getStatistics();
        mvc.perform(get(path).header("Authorization", token)).andExpect(status().isOk()); // warm: caches, first-use metadata
        stats.clear();
        JsonNode body = json.readTree(mvc.perform(get(path).header("Authorization", token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString());
        assertThat(body.get("data").get("content").size()).isPositive();
        return stats.getPrepareStatementCount();
    }

    @Test
    void complaintAndFlagPagesCostTheSameWhetherTheyHoldThreeRowsOrTwenty() throws Exception {
        User admin = user(UserRole.ADMIN, Set.of(AdminPermission.SUPPORT));
        String token = "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", admin.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data").get("accessToken").asText();

        complaints(3);
        long smallComplaints = statementsFor(token, "/admin/complaints?query=" + tag + "&size=20");
        long smallFlags = statementsFor(token, "/admin/flags?query=" + tag + "&size=20");
        complaints(17);
        long bigComplaints = statementsFor(token, "/admin/complaints?query=" + tag + "&size=20");
        long bigFlags = statementsFor(token, "/admin/flags?query=" + tag + "&size=20");

        // 60 users instead of 9 may need one more batched IN query for their permissions, but never one query per row
        assertThat(bigComplaints - smallComplaints).as("complaints: 20 rows vs 3 (N+1)").isLessThanOrEqualTo(2);
        assertThat(bigFlags - smallFlags).as("flags: 20 rows vs 3 (N+1)").isLessThanOrEqualTo(2);
    }
}
