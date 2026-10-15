package com.aiwa.api;

import com.aiwa.support.TestPhones;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** E-1 / AU-09: Super admin and Finance admins must have two-factor on before the admin API answers. */
@SpringBootTest(properties = "aiwa.auth.require-admin-2fa=true")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminTwoFactorApiTest {

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

    private String admin(boolean totp, AdminPermission... perms) throws Exception {
        int n = SEQ.incrementAndGet();
        User u = userRepo.save(User.builder().fullName("admin " + n).email("tfa-admin" + n + "@test.aiwa")
                .phone(TestPhones.next()).password(encoder.encode(PASSWORD))
                .role(UserRole.ADMIN).active(true).termsAccepted(true).totpEnabled(totp)
                .adminPermissions(perms.length == 0 ? new HashSet<>() : new HashSet<>(EnumSet.copyOf(List.of(perms))))
                .build());
        return "Bearer " + json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andReturn().getResponse().getContentAsString()).path("data").path("accessToken").asText();
    }

    @Test
    void aFinanceAdminWithoutTwoFactorIsRefusedButCanReachTheSetup() throws Exception {
        String finance = admin(false, AdminPermission.FINANCE);
        mvc.perform(get("/admin/users").header("Authorization", finance))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("auth.error.admin_2fa_required"));
        mvc.perform(get("/auth/2fa/status").header("Authorization", finance)).andExpect(status().isOk());
    }

    @Test
    void aSuperAdminWithoutTwoFactorIsRefusedToo() throws Exception {
        mvc.perform(get("/admin/users").header("Authorization", admin(false, AdminPermission.SUPER_ADMIN)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("auth.error.admin_2fa_required"));
    }

    // F-03: SUPPORT can read ID documents and edit accounts, so it needs two-factor sign-in too.
    @Test
    void supportAndPermissionlessAdminsAreRefusedToo() throws Exception {
        for (String token : List.of(admin(false, AdminPermission.SUPPORT), admin(false))) {
            mvc.perform(get("/admin/users").header("Authorization", token))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("auth.error.admin_2fa_required"));
        }
    }

    // SA-01: the requirement covers every route an admin capability lives on, not just /admin/**.
    @Test
    void aSuperAdminWithoutTwoFactorCannotPublishTermsOrChangeSupportSettings() throws Exception {
        String superAdmin = admin(false, AdminPermission.SUPER_ADMIN);
        mvc.perform(post("/terms").header("Authorization", superAdmin).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"version\":\"x\",\"body\":\"y\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("auth.error.admin_2fa_required"));
        mvc.perform(patch("/support/admin/settings").header("Authorization", superAdmin)
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("auth.error.admin_2fa_required"));
    }
}
