package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Audit-only: confirms an authenticated caller can exceed the 2FA guess budget. */
@SpringBootTest(properties = {"aiwa.auth.require-admin-2fa=true", "aiwa.auth.max-failed-attempts=5"})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityTotpAuditApiTest {
    @TestConfiguration static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }
    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtUtils jwt;
    @Autowired TotpService totp;
    @Autowired ObjectMapper json;

    @Test
    void enabledAdminCanGuessBeyondAccountBudgetThenMintNewSessionWithoutPassword() throws Exception {
        String secret = totp.generateSecret();
        User admin = users.save(User.builder().fullName("Security audit admin").email("security-audit@example.invalid")
            .password("unused-password-hash").role(UserRole.ADMIN).active(true).totpEnabled(true)
            .totpSecret(secret).adminPermissions(Set.of(AdminPermission.SUPER_ADMIN)).build());
        String access = jwt.generateAccessToken(admin.getEmail(), admin.getId(), "ADMIN");
        // A pre-existing access token is the attack prerequisite. No password, refresh token or MFA challenge supplied.
        int wrong = 0;
        for (int candidate = 0; wrong < 24; candidate++) {
            String code = String.format("%06d", candidate);
            if (totp.verifyCode(secret, code)) continue;
            mvc.perform(post("/auth/2fa/enable").header("Authorization", "Bearer " + access)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("code", code))))
                .andExpect(status().isBadRequest());
            wrong++;
        }
        // The account is still eligible for all five normal sign-in guesses.
        int remaining = users.claimLoginAttempt(admin.getId(), 5, java.time.Instant.now(), java.time.Instant.now().minusSeconds(900));
        assertThat(remaining).isEqualTo(1);
        byte[] key = ReflectionTestUtils.invokeMethod(totp, "base32Decode", secret);
        String valid = ReflectionTestUtils.invokeMethod(totp, "generateCode", key, System.currentTimeMillis()/1000/30);
        var response = mvc.perform(post("/auth/2fa/enable").header("Authorization", "Bearer " + access)
            .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("code", valid))))
            .andExpect(status().isOk()).andReturn().getResponse();
        assertThat(json.readTree(response.getContentAsString()).path("data").path("accessToken").asText()).isNotBlank();
        assertThat(response.getHeaders("Set-Cookie")).anyMatch(cookie -> cookie.startsWith("aiwa_admin_refresh=") && cookie.contains("HttpOnly"));
        System.out.println("AUDIT 2fa-enable: 24 wrong guesses do not spend 5-attempt account budget; valid code issues a new session without password");
    }
}
