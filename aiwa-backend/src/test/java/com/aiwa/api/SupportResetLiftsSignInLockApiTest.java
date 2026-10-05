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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * CR-01 follow-up: support's temporary password also lifts the per-account sign-in lock, so a locked-out user
 * who was given it can sign in at once instead of waiting out the lock period.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SupportResetLiftsSignInLockApiTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(500);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @org.springframework.boot.test.mock.mockito.MockBean com.aiwa.service.EmailService emailService;

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role, Set<AdminPermission> perms) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("reset " + n).email("reset" + n + "@test.aiwa")
                .password(encoder.encode(PASSWORD)).role(role).active(true).termsAccepted(true)
                .adminPermissions(new HashSet<>(perms)).build());
    }

    /** Each request comes from its own IP, so the per-IP limiter never answers for the per-account lock. */
    private MockHttpServletRequestBuilder fromNewIp(MockHttpServletRequestBuilder request, Map<String, String> body)
            throws Exception {
        int n = SEQ.incrementAndGet();
        String ip = "10.2." + (n / 250) + "." + (n % 250);
        return request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body))
                .with(r -> {
                    r.setRemoteAddr(ip);
                    return r;
                });
    }

    private int loginStatus(User u, String password) throws Exception {
        return mvc.perform(fromNewIp(post("/auth/login"), Map.of("identifier", u.getEmail(), "password", password)))
                .andReturn().getResponse().getStatus();
    }

    @Test
    void aLockedUserResetBySupportSignsInWithTheTemporaryPasswordAtOnce() throws Exception {
        User support = user(UserRole.ADMIN, Set.of(AdminPermission.SUPPORT));
        String supportToken = json.readTree(mvc.perform(fromNewIp(post("/auth/login"),
                        Map.of("identifier", support.getEmail(), "password", PASSWORD)))
                .andReturn().getResponse().getContentAsString()).get("data").get("accessToken").asText();
        User locked = user(UserRole.CUSTOMER, Set.of());
        for (int i = 0; i < 5; i++) assertThat(loginStatus(locked, "wrong-pass-" + i)).isEqualTo(401);
        assertThat(loginStatus(locked, PASSWORD)).as("locked").isEqualTo(429);

        String body = mvc.perform(post("/admin/users/" + locked.getId() + "/reset-password")
                        .header("Authorization", "Bearer " + supportToken))
                .andReturn().getResponse().getContentAsString();
        // AU-08: the password goes to the user by email (this user has no phone), not to the admin.
        assertThat(body).doesNotContain("temporaryPassword").doesNotContain("Aiwa-");
        org.mockito.ArgumentCaptor<String> text = org.mockito.ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(emailService).send(org.mockito.ArgumentMatchers.eq(locked.getEmail()),
                org.mockito.ArgumentMatchers.anyString(), text.capture());
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("Aiwa-[A-Za-z0-9]{8}").matcher(text.getValue());
        assertThat(m.find()).isTrue();
        String temporary = m.group();

        assertThat(loginStatus(locked, temporary)).as("the temporary password works at once").isEqualTo(200);
    }

    /** F-17: the temporary password works for a day, then stops; a normal password never expires. */
    @Test
    void aTemporaryPasswordExpires() throws Exception {
        User support = user(UserRole.ADMIN, Set.of(AdminPermission.SUPPORT));
        String supportToken = json.readTree(mvc.perform(fromNewIp(post("/auth/login"),
                        Map.of("identifier", support.getEmail(), "password", PASSWORD)))
                .andReturn().getResponse().getContentAsString()).get("data").get("accessToken").asText();
        User customer = user(UserRole.CUSTOMER, Set.of());

        mvc.perform(post("/admin/users/" + customer.getId() + "/reset-password").header("Authorization", "Bearer " + supportToken));
        org.mockito.ArgumentCaptor<String> text = org.mockito.ArgumentCaptor.forClass(String.class);
        org.mockito.Mockito.verify(emailService, org.mockito.Mockito.atLeastOnce()).send(
                org.mockito.ArgumentMatchers.eq(customer.getEmail()), org.mockito.ArgumentMatchers.anyString(), text.capture());
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("Aiwa-[A-Za-z0-9]{8}").matcher(text.getValue());
        assertThat(m.find()).isTrue();
        String temporary = m.group();

        User stored = userRepo.findById(customer.getId()).orElseThrow();
        assertThat(stored.getTempPasswordExpiresAt()).isAfter(java.time.Instant.now().plus(java.time.Duration.ofHours(23)));
        assertThat(text.getValue()).contains("24 hours");
        assertThat(loginStatus(customer, temporary)).isEqualTo(200);

        stored.setTempPasswordExpiresAt(java.time.Instant.now().minusSeconds(5));
        userRepo.save(stored);
        assertThat(loginStatus(customer, temporary)).as("expired").isEqualTo(401);

        // a password nobody issued temporarily is unaffected
        User plain = user(UserRole.CUSTOMER, Set.of());
        assertThat(plain.hasExpiredTempPassword()).isFalse();
        assertThat(loginStatus(plain, PASSWORD)).isEqualTo(200);
    }
}
