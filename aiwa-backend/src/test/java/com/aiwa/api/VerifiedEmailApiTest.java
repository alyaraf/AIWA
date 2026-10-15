package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
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
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CR-05, at the API level (real filter chain, JPA on H2, in-memory Redis): an
 * email address cannot sign in, reset a password or block a sign-up until its
 * owner confirmed it with a code, and email change, phone change and account
 * deletion need the current password.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class VerifiedEmailApiTest {

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
    private static final String WRONG_PASSWORD = "auth.error.wrong_password";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void resetRedis() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    // ── fixtures ─────────────────────────────────────────────────────────────

    private static String uniquePhone() {
        return "+2011" + String.format("%08d", SEQ.incrementAndGet());
    }

    private static String uniqueEmail() {
        return "cr05-" + SEQ.incrementAndGet() + "@test.aiwa";
    }

    private User user() {
        return userRepo.save(User.builder().fullName("cr05 user").email(uniqueEmail()).phone(uniquePhone())
                .password(encoder.encode(PASSWORD)).role(UserRole.CUSTOMER).active(true).termsAccepted(true).build());
    }

    private User reload(User u) {
        return userRepo.findById(u.getId()).orElseThrow();
    }

    private ResultActions send(MockHttpServletRequestBuilder request, String token, Map<String, ?> body) throws Exception {
        if (token != null) request.header("Authorization", "Bearer " + token);
        if (body != null) request.contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body));
        return mvc.perform(request);
    }

    private JsonNode data(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString()).get("data");
    }

    private int loginStatus(String identifier, String password) throws Exception {
        return send(post("/auth/login"), null, Map.of("identifier", identifier, "password", password))
                .andReturn().getResponse().getStatus();
    }

    private String login(String identifier) throws Exception {
        return data(send(post("/auth/login"), null, Map.of("identifier", identifier, "password", PASSWORD))
                .andExpect(status().isOk())).get("accessToken").asText();
    }

    /** The code the OTP service last issued for this phone or email (what the SMS or email carries). */
    private String codeFor(String destination) {
        return redis.get("otp:code:" + destination).orElseThrow();
    }

    /** send-otp + verify-otp: what the app does before /auth/register. */
    private String proveOwnership(String field, String destination) throws Exception {
        send(post("/auth/send-otp"), null, Map.of(field, destination)).andExpect(status().isOk());
        return data(send(post("/auth/verify-otp"), null, Map.of(field, destination, "code", codeFor(destination)))
                .andExpect(status().isOk())).get("receipt").asText();
    }

    // ── email change ─────────────────────────────────────────────────────────

    @Test
    void anEmailChangeNeedsThePasswordAndIsNotUsedUntilItsOwnerConfirmsIt() throws Exception {
        User u = user();
        String oldEmail = u.getEmail();
        String newEmail = uniqueEmail();
        String otherSession = login(oldEmail);
        String session = login(oldEmail);

        // A session alone is not enough: no password, or a wrong one, is refused.
        send(patch("/auth/me"), session, Map.of("fullName", "N", "email", newEmail))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        send(patch("/auth/me"), session, Map.of("fullName", "N", "email", newEmail, "currentPassword", "not-it"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        assertThat(reload(u).getEmail()).isEqualTo(oldEmail);

        // With the password the address only waits for confirmation.
        send(patch("/auth/me"), session, Map.of("fullName", "N", "email", newEmail, "currentPassword", PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value(oldEmail))
                .andExpect(jsonPath("$.data.pendingEmail").value(newEmail));
        assertThat(reload(u).getEmail()).isEqualTo(oldEmail);
        send(get("/auth/me"), session, null).andExpect(jsonPath("$.data.pendingEmail").value(newEmail));

        // Until then it does not sign in, and "forgot password" by it does not reach the account.
        assertThat(loginStatus(newEmail, PASSWORD)).isEqualTo(401);
        send(post("/auth/send-otp"), null, Map.of("email", newEmail)).andExpect(status().isOk());
        send(post("/auth/reset-password"), null,
                Map.of("email", newEmail, "code", codeFor(newEmail), "newPassword", "Attacker123!"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("auth.error.email_not_found"));
        assertThat(loginStatus(oldEmail, "Attacker123!")).isEqualTo(401);
        assertThat(loginStatus(oldEmail, PASSWORD)).isEqualTo(200);

        // Asking again sends a new code; a wrong code confirms nothing.
        send(patch("/auth/me"), session, Map.of("fullName", "N", "email", newEmail, "currentPassword", PASSWORD))
                .andExpect(status().isOk());
        String code = codeFor(newEmail);
        send(post("/auth/me/email/verify"), session, Map.of("code", code.equals("000000") ? "000001" : "000000"))
                .andExpect(status().isBadRequest());
        assertThat(reload(u).getEmail()).isEqualTo(oldEmail);

        // The right code sets the email, signs every other session out and hands back new tokens.
        JsonNode auth = data(send(post("/auth/me/email/verify"), session, Map.of("code", code))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.user.email").value(newEmail)));
        assertThat(reload(u).getEmail()).isEqualTo(newEmail);
        send(get("/auth/me"), otherSession, null).andExpect(status().isUnauthorized());
        send(get("/auth/me"), auth.get("accessToken").asText(), null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.email").value(newEmail))
                .andExpect(jsonPath("$.data.pendingEmail").doesNotExist());
        assertThat(loginStatus(newEmail, PASSWORD)).isEqualTo(200);
        assertThat(loginStatus(oldEmail, PASSWORD)).isEqualTo(401);
    }

    // AP-02: each new address got a code with no per-account limit, and every send spent the shared
    // OTP budget, so one account could mail strangers until sign-up and reset codes stopped for everyone.
    @Test
    void anAccountMailsOnlyAFewEmailChangeCodesPerHourAndARefusedOneSpendsNoBudget() throws Exception {
        User u = user();
        String session = login(u.getEmail());
        int allowed = com.aiwa.controller.AuthController.EMAIL_CHANGE_SENDS_PER_HOUR;
        for (int i = 0; i < allowed; i++) {
            send(patch("/auth/me"), session, Map.of("fullName", "N", "email", uniqueEmail(), "currentPassword", PASSWORD))
                    .andExpect(status().isOk());
        }
        String refused = uniqueEmail();
        send(patch("/auth/me"), session, Map.of("fullName", "N", "email", refused, "currentPassword", PASSWORD))
                .andExpect(status().isTooManyRequests());
        assertThat(redis.get("otp:code:" + refused)).isEmpty();
        assertThat(redis.get("otp:global:hour")).contains(String.valueOf(allowed));
        assertThat(reload(u).getPendingEmail()).isNotEqualTo(refused);
    }

    // ── sign-up by phone with someone else's email ───────────────────────────

    // SA-03: a number someone else proved cannot be registered by a caller who lacks the receipt.
    @Test
    void aVerifiedNumberCannotBeRegisteredWithoutTheReceiptOfWhoeverVerifiedIt() throws Exception {
        String phone = uniquePhone();
        String receipt = proveOwnership("phone", phone);
        Map<String, Object> body = new java.util.HashMap<>(Map.of("fullName", "Intruder", "phone", phone,
                "password", PASSWORD, "role", "CUSTOMER"));
        send(post("/auth/register"), null, body).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.phone_not_verified"));
        body.put("verificationReceipt", "not-the-receipt");
        send(post("/auth/register"), null, body).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("auth.error.phone_not_verified"));
        body.put("verificationReceipt", receipt);
        send(post("/auth/register"), null, body).andExpect(status().isCreated());
    }

    @Test
    void aPhoneSignUpWithSomeoneElsesEmailNeitherBlocksTheOwnerNorCatchesTheirReset() throws Exception {
        String victimEmail = uniqueEmail();
        String attackerPhone = uniquePhone();

        // The attacker signs up by phone and names the victim's email.
        String attackerReceipt = proveOwnership("phone", attackerPhone);
        JsonNode attacker = data(send(post("/auth/register"), null, Map.of("fullName", "Attacker", "phone", attackerPhone,
                "email", victimEmail, "password", PASSWORD, "role", "CUSTOMER", "verificationReceipt", attackerReceipt))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.user.email").doesNotExist())
                .andExpect(jsonPath("$.data.user.pendingEmail").value(victimEmail)));
        long attackerId = attacker.get("user").get("id").asLong();

        // The owner of the address can still register with it.
        String victimReceipt = proveOwnership("email", victimEmail);
        JsonNode victim = data(send(post("/auth/register"), null, Map.of("fullName", "Victim", "email", victimEmail,
                "password", "Victim123!", "role", "CUSTOMER", "verificationReceipt", victimReceipt))
                .andExpect(status().isCreated()));
        long victimId = victim.get("user").get("id").asLong();
        assertThat(victimId).isNotEqualTo(attackerId);

        // "Forgot password" by that email changes the owner's password, never the phone account's.
        send(post("/auth/send-otp"), null, Map.of("email", victimEmail)).andExpect(status().isOk());
        send(post("/auth/reset-password"), null,
                Map.of("email", victimEmail, "code", codeFor(victimEmail), "newPassword", "Changed123!"))
                .andExpect(status().isOk());
        assertThat(loginStatus(attackerPhone, "Changed123!")).isEqualTo(401);
        assertThat(loginStatus(attackerPhone, PASSWORD)).isEqualTo(200);
        JsonNode signedIn = data(send(post("/auth/login"), null,
                Map.of("identifier", victimEmail, "password", "Changed123!")).andExpect(status().isOk()));
        assertThat(signedIn.get("user").get("id").asLong()).isEqualTo(victimId);

        // The code that reset sent does not confirm the attacker's claim on the address either.
        assertThat(userRepo.findById(attackerId).orElseThrow().getEmail()).isNull();
    }

    // ── phone change, account deletion ───────────────────────────────────────

    @Test
    void aPhoneChangeNeedsTheCurrentPassword() throws Exception {
        User u = user();
        String oldPhone = u.getPhone();
        String newPhone = uniquePhone();
        String session = login(u.getEmail());
        send(post("/auth/send-otp"), null, Map.of("phone", newPhone)).andExpect(status().isOk());
        String code = codeFor(newPhone);

        send(patch("/auth/me/phone"), session, Map.of("phone", newPhone, "code", code))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        send(patch("/auth/me/phone"), session, Map.of("phone", newPhone, "code", code, "currentPassword", "not-it"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        assertThat(reload(u).getPhone()).isEqualTo(oldPhone);

        // With the password it works as before: number changed, new tokens.
        JsonNode auth = data(send(patch("/auth/me/phone"), session,
                Map.of("phone", newPhone, "code", code, "currentPassword", PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.user.phone").value(newPhone)));
        assertThat(reload(u).getPhone()).isEqualTo(newPhone);
        send(get("/auth/me"), auth.get("accessToken").asText(), null).andExpect(status().isOk());
        send(get("/auth/me"), session, null).andExpect(status().isUnauthorized());
    }

    @Test
    void deletingTheAccountNeedsTheCurrentPassword() throws Exception {
        User u = user();
        String session = login(u.getEmail());

        send(delete("/account"), session, null)
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        send(delete("/account"), session, Map.of("currentPassword", "not-it"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        assertThat(reload(u).isActive()).isTrue();

        // With the password it works as before: anonymised, disabled, signed out.
        send(delete("/account"), session, Map.of("currentPassword", PASSWORD)).andExpect(status().isOk());
        assertThat(reload(u).isActive()).isFalse();
        assertThat(reload(u).getEmail()).isNull();
        send(get("/auth/me"), session, null).andExpect(status().isUnauthorized());
    }

    // AP-01: the last super admin could close their own account here, leaving no active super admin;
    // the bootstrap rule then let any admin create super admins. Admins are removed from the panel.
    @Test
    void anAdminCannotCloseTheirOwnAccountFromTheApp() throws Exception {
        for (com.aiwa.enums.AdminPermission perm : com.aiwa.enums.AdminPermission.values()) {
            User admin = userRepo.save(User.builder().fullName("ap01 " + perm).email(uniqueEmail()).phone(uniquePhone())
                    .password(encoder.encode(PASSWORD)).role(UserRole.ADMIN).active(true).termsAccepted(true)
                    .adminPermissions(new java.util.HashSet<>(java.util.Set.of(perm))).build());
            String session = login(admin.getEmail());
            send(delete("/account"), session, Map.of("currentPassword", PASSWORD))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("account.error.admin_self_delete"));
            User after = reload(admin);
            assertThat(after.isActive()).isTrue();
            assertThat(after.getEmail()).isEqualTo(admin.getEmail());
            send(get("/auth/me"), session, null).andExpect(status().isOk());
        }
    }

    @Test
    void wrongPasswordsOnASensitiveChangeCountTowardTheAccountLock() throws Exception {
        User u = user();
        String session = login(u.getEmail());

        for (int i = 0; i < 5; i++) {
            send(delete("/account"), session, Map.of("currentPassword", "guess-" + i))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value(WRONG_PASSWORD));
        }
        // The cap from CR-01: the sixth try is refused even with the right password.
        send(delete("/account"), session, Map.of("currentPassword", PASSWORD))
                .andExpect(status().isTooManyRequests());
        assertThat(reload(u).isActive()).isTrue();
    }
}
