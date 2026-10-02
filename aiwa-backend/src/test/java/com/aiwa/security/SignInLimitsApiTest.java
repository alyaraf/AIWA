package com.aiwa.security;

import com.aiwa.entity.User;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.net.URI;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/**
 * CR-01, at the API level (real filter chain, JPA on H2, in-memory Redis): the
 * per-IP limit cannot be skipped with a percent-encoded path, and password and
 * 2FA guesses are capped per account and per challenge.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SignInLimitsApiTest {

    @TestConfiguration
    static class Config {
        @Bean
        @Primary
        RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(100);
    private static final String PASSWORD = "Secret123!";
    private static final String SECRET = "JBSWY3DPEHPK3PXP";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    @Autowired JdbcTemplate jdbc;

    private final TotpService totp = new TotpService();

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    // ── fixtures ─────────────────────────────────────────────────────────────

    private User user(boolean twoFactor) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder()
                .fullName("limits " + n).email("limits" + n + "@test.aiwa")
                .password(encoder.encode(PASSWORD))
                .role(twoFactor ? UserRole.ADMIN : UserRole.CUSTOMER).active(true).termsAccepted(true)
                .totpEnabled(twoFactor).totpSecret(twoFactor ? SECRET : null)
                .build());
    }

    /** Every request comes from its own IP, so the per-IP limiter never answers for the per-account one. */
    private MockHttpServletRequestBuilder fromNewIp(MockHttpServletRequestBuilder request, Map<String, String> body)
            throws Exception {
        String ip = "10.1." + (SEQ.incrementAndGet() / 250) + "." + (SEQ.get() % 250);
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

    /** Password step of a 2FA sign-in: returns the challenge token. */
    private String challenge(User u) throws Exception {
        String body = mvc.perform(fromNewIp(post("/auth/login"),
                        Map.of("identifier", u.getEmail(), "password", PASSWORD)))
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("data").get("mfaToken").asText();
    }

    private int verifyStatus(String mfaToken, String code) throws Exception {
        return mvc.perform(fromNewIp(post("/auth/2fa/verify"), Map.of("mfaToken", mfaToken, "code", code)))
                .andReturn().getResponse().getStatus();
    }

    private static long step() {
        return System.currentTimeMillis() / 1000 / 30;
    }

    private String currentCode() {
        return totp.generateCode(TotpService.base32Decode(SECRET), step());
    }

    /** A well-formed code that matches no time step anywhere near now. */
    private String wrongCode() {
        Set<String> near = new HashSet<>();
        for (long s = step() - 5; s <= step() + 5; s++) near.add(totp.generateCode(TotpService.base32Decode(SECRET), s));
        for (int i = 0; ; i++) {
            String code = String.format("%06d", i);
            if (!near.contains(code)) return code;
        }
    }

    /** The clock moves on: the account's last counted attempt is now 16 minutes old (the lock lasts 15). */
    private void lockPeriodPasses(User u) {
        jdbc.update("UPDATE users SET last_failed_login_at = ? WHERE id = ?",
                OffsetDateTime.now().minusMinutes(16), u.getId());
    }

    // ── per-IP limit: encoded path ───────────────────────────────────────────

    @Test
    void anEncodedLoginPathGetsTheSameIpLimitAsThePlainOne() throws Exception {
        String body = json.writeValueAsString(Map.of("identifier", "nobody@test.aiwa", "password", "wrong-pass"));
        List<Integer> statuses = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            // Spring MVC decodes %6e to "n" and routes this to the login handler.
            statuses.add(mvc.perform(post(URI.create("/auth/logi%6e")).contentType(MediaType.APPLICATION_JSON)
                    .content(body)).andReturn().getResponse().getStatus());
        }
        System.out.println("CR-01 encoded path /auth/logi%6e, statuses of 11 POSTs from one IP: " + statuses);

        // The handler is reached (wrong credentials), so the limit must apply: 10 a minute, the 11th is refused.
        assertThat(statuses.subList(0, 10)).containsOnly(401);
        assertThat(statuses.get(10)).isEqualTo(429);
        // Same budget as the plain spelling, not a second one.
        assertThat(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON).content(body))
                .andReturn().getResponse().getStatus()).isEqualTo(429);
    }

    // ── per-account cap ──────────────────────────────────────────────────────

    @Test
    void sixWrongPasswordsLockTheAccountUntilTheLockPeriodPasses() throws Exception {
        User u = user(false);
        for (int i = 0; i < 5; i++) assertThat(loginStatus(u, "wrong-pass-" + i)).isEqualTo(401);

        assertThat(loginStatus(u, "wrong-pass-6")).isEqualTo(429);
        assertThat(loginStatus(u, PASSWORD)).isEqualTo(429); // the right password is refused too

        lockPeriodPasses(u);
        assertThat(loginStatus(u, PASSWORD)).isEqualTo(200);
    }

    @Test
    void aSuccessfulSignInResetsTheFailureCount() throws Exception {
        User u = user(false);
        for (int round = 0; round < 2; round++) {
            for (int i = 0; i < 4; i++) assertThat(loginStatus(u, "wrong-pass-" + i)).isEqualTo(401);
            assertThat(loginStatus(u, PASSWORD)).isEqualTo(200);
        }
    }

    @Test
    void wrongTwoFactorCodesCountAgainstTheAccountAcrossChallenges() throws Exception {
        User u = user(true);
        String wrong = wrongCode();
        // The password is known; a new challenge for every guess must not give new guesses.
        for (int i = 0; i < 5; i++) assertThat(verifyStatus(challenge(u), wrong)).isEqualTo(400);

        assertThat(loginStatus(u, PASSWORD)).isEqualTo(429);
    }

    // ── per-challenge cap ────────────────────────────────────────────────────

    @Test
    void fiveWrongCodesKillTheChallenge() throws Exception {
        User u = user(true);
        String mfaToken = challenge(u);
        String wrong = wrongCode();
        for (int i = 0; i < 5; i++) assertThat(verifyStatus(mfaToken, wrong)).isEqualTo(400);

        assertThat(verifyStatus(mfaToken, currentCode())).isEqualTo(401);
        // Not just the account lock: the challenge stays dead after the lock period.
        lockPeriodPasses(u);
        assertThat(verifyStatus(mfaToken, currentCode())).isEqualTo(401);
        // Signing in again gives a fresh challenge that works.
        assertThat(verifyStatus(challenge(u), currentCode())).isEqualTo(200);
    }

    // ── a code works once ────────────────────────────────────────────────────

    @Test
    void aTotpCodeAcceptedOnceIsRefusedTheSecondTime() throws Exception {
        User u = user(true);
        String code = currentCode();
        String body = mvc.perform(fromNewIp(post("/auth/2fa/verify"), Map.of("mfaToken", challenge(u), "code", code)))
                .andReturn().getResponse().getContentAsString();
        String access = json.readTree(body).get("data").get("accessToken").asText();

        // Same code, still inside its window: not for a second sign-in…
        assertThat(verifyStatus(challenge(u), code)).isEqualTo(400);
        // …and not to confirm turning 2FA off.
        assertThat(mvc.perform(fromNewIp(post("/auth/2fa/disable"), Map.of("password", PASSWORD, "code", code))
                        .header("Authorization", "Bearer " + access))
                .andReturn().getResponse().getStatus()).isEqualTo(400);
        assertThat(userRepo.findById(u.getId()).orElseThrow().isTotpEnabled()).isTrue();
    }
}
