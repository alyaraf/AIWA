package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
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

import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * S-05: sensitive admin reads and bulk exports are gated by capability, not by "any admin".
 * An admin with no permission, or the wrong one, gets 403 on each restricted route.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminReadExportRbacApiTest {

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
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void resetLimits() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private String admin(AdminPermission... perms) throws Exception {
        int n = SEQ.incrementAndGet();
        User u = userRepo.save(User.builder().fullName("rbac admin " + n)
                .email("rbac-admin" + n + "@test.aiwa")
                .phone("+2010885" + String.format("%05d", n))
                .password(encoder.encode(PASSWORD)).role(UserRole.ADMIN).active(true).termsAccepted(true)
                .adminPermissions(perms.length == 0 ? new HashSet<>() : new HashSet<>(EnumSet.copyOf(List.of(perms))))
                .build());
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andReturn().getResponse().getContentAsString()).get("data").get("accessToken").asText();
    }

    private void forbidden(String path, String token) throws Exception {
        mvc.perform(get(path).header("Authorization", token)).andExpect(status().isForbidden());
    }

    private void allowed(String path, String token) throws Exception {
        mvc.perform(get(path).header("Authorization", token)).andExpect(status().isOk());
    }

    @Test
    void auditLogIsSuperAdminOnly() throws Exception {
        String none = admin();
        String support = admin(AdminPermission.SUPPORT);
        String finance = admin(AdminPermission.FINANCE);
        for (String path : List.of("/admin/audit", "/admin/audit/export")) {
            forbidden(path, none);
            forbidden(path, support);
            forbidden(path, finance);
            allowed(path, admin(AdminPermission.SUPER_ADMIN));
        }
    }

    @Test
    void settlementReadsAndLedgerExportNeedFinance() throws Exception {
        String none = admin();
        String support = admin(AdminPermission.SUPPORT);
        String finance = admin(AdminPermission.FINANCE);
        for (String path : List.of("/admin/settlements", "/admin/settlements/overview",
                "/admin/settlements/providers", "/admin/settlements/export")) {
            forbidden(path, none);
            forbidden(path, support);
            allowed(path, finance);
        }
    }

    @Test
    void bookingListsAndCsvExportsNeedSupportOrFinance() throws Exception {
        String none = admin();
        for (String path : List.of("/admin/bookings", "/admin/bookings/export", "/admin/analytics/export")) {
            forbidden(path, none);
            allowed(path, admin(AdminPermission.SUPPORT));
            allowed(path, admin(AdminPermission.FINANCE));
        }
    }

    /** F-04: user lists, details and the complaint/verification/moderation queues hold PII; an admin with no permission is refused. */
    @Test
    void personalDataReadsNeedSupportOrFinance() throws Exception {
        String none = admin();
        for (String path : List.of("/admin/users", "/admin/complaints", "/admin/verification/pending",
                "/admin/verification?status=APPROVED", "/admin/moderation")) {
            forbidden(path, none);
        }
        allowed("/admin/users", admin(AdminPermission.FINANCE));
        for (String path : List.of("/admin/users", "/admin/complaints", "/admin/verification/pending", "/admin/moderation")) {
            allowed(path, admin(AdminPermission.SUPPORT));
        }
    }

    /** F-06: settling one ledger entry needs the amount and a payment reference. */
    @Test
    void settlingASingleEntryNeedsAmountAndReference() throws Exception {
        String finance = admin(AdminPermission.FINANCE);
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch("/admin/settlements/999999/settle")
                .header("Authorization", finance)).andExpect(status().isNotFound());
        String support = admin(AdminPermission.SUPPORT);
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch("/admin/settlements/1/settle")
                .param("expectedAmount", "10").param("reference", "TX1")
                .header("Authorization", support)).andExpect(status().isForbidden());
    }
}
