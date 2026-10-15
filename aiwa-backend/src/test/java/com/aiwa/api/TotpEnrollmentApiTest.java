package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.JwtUtils;
import com.aiwa.security.TotpService;
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
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SEC-03 (security audit 2026-10-06): POST /auth/2fa/enable only confirms a live, one-time pending
 * enrollment, spends a per-enrollment attempt budget kept in the database, refuses an account that already
 * has 2FA on, and is throttled per IP. Replaces the audit's SecurityTotpAuditApiTest defect probe.
 */
@SpringBootTest(properties = {"aiwa.auth.max-failed-attempts=5", "aiwa.auth.totp-enroll-max-attempts=5"})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TotpEnrollmentApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(1000);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtUtils jwt;
    @Autowired ObjectMapper json;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;
    private final TotpService totp = new TotpService();

    @BeforeEach
    void freshRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(boolean enabled, String secret, Instant enrollmentExpires) {
        int n = SEQ.incrementAndGet();
        return users.save(User.builder().fullName("totp enrol " + n).email("totp-enrol" + n + "@test.aiwa")
                .phone("+2010793" + String.format("%05d", n)).password(encoder.encode(PASSWORD))
                .role(UserRole.CUSTOMER).active(true).termsAccepted(true).totpEnabled(enabled).totpSecret(enabled ? secret : null).totpPendingSecret(enabled ? null : secret)
                .totpEnrollmentExpiresAt(enrollmentExpires).build());
    }

    private String access(User u) {
        return "Bearer " + jwt.generateAccessToken(u.getEmail(), u.getId(), "CUSTOMER");
    }

    private String validCode(String secret) {
        long step = System.currentTimeMillis() / 1000 / TotpService.stepSeconds();
        byte[] key = org.springframework.test.util.ReflectionTestUtils.invokeMethod(TotpService.class, "base32Decode", secret);
        return org.springframework.test.util.ReflectionTestUtils.invokeMethod(totp, "generateCode", key, step);
    }

    private String wrongCode(String secret) {
        for (int c = 0; ; c++) {
            String code = String.format("%06d", c);
            if (!totp.verifyCode(secret, code)) return code;
        }
    }

    private static RequestPostProcessor fromIp(String ip) {
        return r -> { r.setRemoteAddr(ip); return r; };
    }

    private MvcResult enable(String bearer, String code, String ip) throws Exception {
        return mvc.perform(post("/auth/2fa/enable").with(fromIp(ip)).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("code", code))))
                .andReturn();
    }

    private JsonNode setup(String bearer) throws Exception {
        MvcResult r = mvc.perform(post("/auth/2fa/setup").with(fromIp("10.9.9.9")).header("Authorization", bearer)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("password", PASSWORD))))
                .andExpect(status().isOk()).andReturn();
        return json.readTree(r.getResponse().getContentAsString()).path("data");
    }

    @Test
    void excessWrongCodesAreThrottledAcrossIpsAndEvenWhenRedisForgetsEverything() throws Exception {
        String secret = totp.generateSecret();
        User u = user(false, secret, Instant.now().plusSeconds(600));
        String bearer = access(u);

        for (int i = 0; i < 5; i++) {
            ((InMemoryRedisRuntimeService) redis).clear(); // Redis lost its counters; the database count stands
            assertThat(enable(bearer, wrongCode(secret), "10.1.0." + i).getResponse().getStatus()).isEqualTo(400);
        }
        assertThat(users.findById(u.getId()).orElseThrow().getTotpEnrollmentAttempts()).isEqualTo(5);

        // The sixth attempt, from yet another IP, is refused, and so is the correct code afterwards.
        assertThat(enable(bearer, wrongCode(secret), "10.2.0.1").getResponse().getStatus()).isEqualTo(429);
        MvcResult correct = enable(bearer, validCode(secret), "10.2.0.2");
        assertThat(correct.getResponse().getStatus()).isEqualTo(400); // enrollment closed, not "expired-then-guessable"
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isFalse();
    }

    @Test
    void theEndpointItselfIsThrottledPerIp() throws Exception {
        String secret = totp.generateSecret();
        User u = user(false, secret, Instant.now().plusSeconds(600));
        String bearer = access(u);
        int tooMany = 0;
        for (int i = 0; i < 12; i++) {
            if (enable(bearer, wrongCode(secret), "10.3.0.1").getResponse().getStatus() == 429) tooMany++;
        }
        // Requests 1-5 spend the enrollment budget (400); 6-10 find the enrollment closed (400) or are throttled;
        // 11-12 exceed the 10-per-minute endpoint limit for this IP (429) whatever the account state.
        assertThat(tooMany).isGreaterThanOrEqualTo(2);
        assertThat(users.findById(u.getId()).orElseThrow().getTotpEnrollmentAttempts()).isEqualTo(5);
    }

    @Test
    void anAlreadyEnabledAccountCannotObtainASessionThroughEnable() throws Exception {
        String secret = totp.generateSecret();
        User u = user(true, secret, null);
        MvcResult r = enable(access(u), validCode(secret), "10.4.0.1");
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(r.getResponse().getContentAsString()).contains("auth.error.totp_already_enabled");
        assertThat(r.getResponse().getHeaders("Set-Cookie")).isEmpty();
        assertThat(r.getResponse().getContentAsString()).doesNotContain("accessToken");
    }

    @Test
    void anExpiredOrMissingEnrollmentCannotBeConfirmedEvenWithTheRightCode() throws Exception {
        String secret = totp.generateSecret();
        User expired = user(false, secret, Instant.now().minusSeconds(5));
        MvcResult r = enable(access(expired), validCode(secret), "10.5.0.1");
        assertThat(r.getResponse().getStatus()).isEqualTo(400);
        assertThat(r.getResponse().getContentAsString()).contains("auth.error.totp_enrollment_expired");
        assertThat(users.findById(expired.getId()).orElseThrow().isTotpEnabled()).isFalse();

        User neverOpened = user(false, secret, null);
        assertThat(enable(access(neverOpened), validCode(secret), "10.5.0.2").getResponse().getStatus()).isEqualTo(400);
        assertThat(users.findById(neverOpened.getId()).orElseThrow().isTotpEnabled()).isFalse();
    }

    @Test
    void legitimateSetupWorksOnceEndsOldSessionsAndCannotBeReplayed() throws Exception {
        User u = user(false, null, null);
        String oldBearer = access(u);
        JsonNode started = setup(oldBearer);
        String secret = started.path("secret").asText();
        assertThat(secret).isNotBlank();

        MvcResult ok = enable(oldBearer, validCode(secret), "10.6.0.1");
        assertThat(ok.getResponse().getStatus()).isEqualTo(200);
        String newAccess = json.readTree(ok.getResponse().getContentAsString()).path("data").path("accessToken").asText();
        assertThat(newAccess).isNotBlank();
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isTrue();

        mvc.perform(get("/auth/me").header("Authorization", oldBearer)).andExpect(status().isUnauthorized());
        mvc.perform(get("/auth/me").header("Authorization", "Bearer " + newAccess)).andExpect(status().isOk());

        // Replay of the same code with the new token: refused (enabled account, and the step is spent).
        assertThat(enable("Bearer " + newAccess, validCode(secret), "10.6.0.2").getResponse().getStatus()).isEqualTo(400);
    }

    @Test
    void settingUpAgainWhenEnabledStillNeedsThePasswordAndTheCurrentCode() throws Exception {
        String secret = totp.generateSecret();
        User u = user(true, secret, null);
        mvc.perform(post("/auth/2fa/setup").with(fromIp("10.7.0.1")).header("Authorization", access(u))
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(Map.of("password", PASSWORD))))
                .andExpect(status().isBadRequest());
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isTrue();
    }

    /** A code works once per 30 s step (CR-01); this stands in for waiting for the next step. */
    private void forgetUsedCode(User u) {
        users.findById(u.getId()).ifPresent(x -> { x.setTotpLastUsedStep(null); users.saveAndFlush(x); });
    }

    private JsonNode signIn(User u) throws Exception {
        return json.readTree(mvc.perform(post("/auth/login").with(fromIp("10.10.0.1")).contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).path("data");
    }

    private int verify(User u, String code) throws Exception {
        forgetUsedCode(u);
        return mvc.perform(post("/auth/2fa/verify").with(fromIp("10.10.0.2")).contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("mfaToken", signIn(u).path("mfaToken").asText(), "code", code))))
                .andReturn().getResponse().getStatus();
    }

    // Archived SA-02 follow-up: a re-setup used to switch 2FA off until the new secret was confirmed,
    // so the password alone could sign in (and enrol its own authenticator) in that window, or forever
    // after an abandoned setup.
    @Test
    void reSetupKeepsTwoFactorOnWithTheOldSecretUntilTheNewOneIsConfirmed() throws Exception {
        String secret = totp.generateSecret();
        User u = user(true, secret, null);
        String bearer = access(u);
        String pending = mvc.perform(post("/auth/2fa/setup").with(fromIp("10.11.0.1")).header("Authorization", bearer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD, "code", validCode(secret)))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        pending = json.readTree(pending).path("data").path("secret").asText();
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isTrue();

        // The window: the password alone gets a challenge, not a session.
        JsonNode passwordOnly = signIn(u);
        assertThat(passwordOnly.path("mfaRequired").asBoolean()).isTrue();
        assertThat(passwordOnly.path("accessToken").isMissingNode() || passwordOnly.path("accessToken").isNull()).isTrue();
        // Until confirmed, the pending secret does not sign in and the old one does.
        assertThat(verify(u, validCode(pending))).isEqualTo(400);
        assertThat(verify(u, validCode(secret))).isEqualTo(200);

        // Confirming switches over: the new secret signs in, the old one no longer does.
        forgetUsedCode(u);
        assertThat(enable(bearer, validCode(pending), "10.11.0.2").getResponse().getStatus()).isEqualTo(200);
        User after = users.findById(u.getId()).orElseThrow();
        assertThat(after.isTotpEnabled()).isTrue();
        assertThat(after.getTotpPendingSecret()).isNull();
        assertThat(verify(u, validCode(secret))).isEqualTo(400);
        assertThat(verify(u, validCode(pending))).isEqualTo(200);
    }

    @Test
    void usingUpTheReSetupBudgetLeavesTheOldSecretOn() throws Exception {
        String secret = totp.generateSecret();
        User u = user(true, secret, null);
        String bearer = access(u);
        String pending = json.readTree(mvc.perform(post("/auth/2fa/setup").with(fromIp("10.12.0.1")).header("Authorization", bearer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD, "code", validCode(secret)))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).path("data").path("secret").asText();
        for (int i = 0; i < 5; i++) enable(bearer, wrongCode(pending), "10.12.1." + i);
        assertThat(enable(bearer, wrongCode(pending), "10.12.2.1").getResponse().getStatus()).isEqualTo(429);
        User after = users.findById(u.getId()).orElseThrow();
        assertThat(after.isTotpEnabled()).isTrue();
        assertThat(after.getTotpPendingSecret()).isNull();
        assertThat(verify(u, validCode(secret))).isEqualTo(200);
    }

    @Test
    void turningTwoFactorOffEndsEarlierSessionsAndHandsOverANewOne() throws Exception {
        String secret = totp.generateSecret();
        User u = user(true, secret, null);
        String other = access(u), caller = access(u);
        MvcResult off = mvc.perform(post("/auth/2fa/disable").with(fromIp("10.13.0.1")).header("Authorization", caller)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", PASSWORD, "code", validCode(secret)))))
                .andExpect(status().isOk()).andReturn();
        String fresh = json.readTree(off.getResponse().getContentAsString()).path("data").path("accessToken").asText();
        assertThat(fresh).isNotBlank();
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isFalse();
        mvc.perform(get("/auth/me").header("Authorization", other)).andExpect(status().isUnauthorized());
        mvc.perform(get("/auth/me").header("Authorization", caller)).andExpect(status().isUnauthorized());
        mvc.perform(get("/auth/me").header("Authorization", "Bearer " + fresh)).andExpect(status().isOk());
    }

    @Test
    void parallelConfirmationsOfTheSameCodeYieldExactlyOneSession() throws Exception {
        User u = user(false, null, null);
        String bearer = access(u);
        String secret = setup(bearer).path("secret").asText();
        String code = validCode(secret);
        ExecutorService pool = Executors.newFixedThreadPool(4);
        try {
            CountDownLatch go = new CountDownLatch(1);
            java.util.List<Future<Integer>> results = new java.util.ArrayList<>();
            for (int i = 0; i < 4; i++) {
                int n = i;
                results.add(pool.submit(() -> {
                    go.await();
                    return enable(bearer, code, "10.8.0." + n).getResponse().getStatus();
                }));
            }
            go.countDown();
            int ok = 0;
            for (Future<Integer> f : results) if (f.get(30, TimeUnit.SECONDS) == 200) ok++;
            assertThat(ok).isEqualTo(1);
        } finally {
            pool.shutdownNow();
        }
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isTrue();
    }
}
