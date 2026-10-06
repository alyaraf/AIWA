package com.aiwa.security;

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
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** SA-02: turning two-factor on ends the sessions issued before it. */
@SpringBootTest(properties = "aiwa.auth.require-admin-2fa=true")
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminTwoFactorEnrolmentApiTest {

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

    // SA-02: sessions issued before two-factor was switched on stop working when it is.
    @Test
    void enablingTwoFactorEndsTheEarlierSessionsAndHandsOverANewOne() throws Exception {
        String secret = new TotpService().generateSecret();
        int n = SEQ.incrementAndGet();
        User u = userRepo.save(User.builder().fullName("enrol " + n).email("tfa-enrol" + n + "@test.aiwa")
                .phone("+2010782" + String.format("%05d", n)).password(encoder.encode(PASSWORD))
                .role(UserRole.ADMIN).active(true).termsAccepted(true).totpEnabled(false).totpSecret(secret).totpEnrollmentExpiresAt(java.time.Instant.now().plusSeconds(600))
                .adminPermissions(new HashSet<>(EnumSet.of(AdminPermission.FINANCE))).build());
        var login = json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andReturn().getResponse().getContentAsString()).path("data");
        String oldAccess = "Bearer " + login.path("accessToken").asText();
        String oldRefresh = login.path("refreshToken").asText();

        TotpService totp = new TotpService();
        long step = System.currentTimeMillis() / 1000 / TotpService.stepSeconds();
        String code = totp.generateCode(TotpService.base32Decode(secret), step);
        var enabled = json.readTree(mvc.perform(post("/auth/2fa/enable").header("Authorization", oldAccess)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).path("data");
        assertThat(enabled.path("accessToken").asText()).isNotBlank();

        mvc.perform(get("/admin/users").header("Authorization", oldAccess)).andExpect(status().isUnauthorized());
        mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + oldRefresh + "\"}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/admin/users").header("Authorization", "Bearer " + enabled.path("accessToken").asText()))
                .andExpect(status().isOk());
    }
}
