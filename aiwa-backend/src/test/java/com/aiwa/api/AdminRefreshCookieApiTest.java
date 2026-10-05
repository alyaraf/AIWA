package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.Cookie;
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

import java.util.EnumSet;
import java.util.HashSet;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * F-05: an admin's refresh token travels only in an HttpOnly, SameSite=Strict cookie scoped to /auth;
 * the JSON body never carries it. Other users keep getting it in the body (the mobile apps).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminRefreshCookieApiTest {

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
    private static final String COOKIE = "aiwa_admin_refresh";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void reset() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User user(UserRole role) {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("cookie " + n).email("cookie" + n + "@test.aiwa")
                .phone("+2010991" + String.format("%05d", n)).password(encoder.encode(PASSWORD)).role(role)
                .active(true).termsAccepted(true)
                .adminPermissions(role == UserRole.ADMIN ? new HashSet<>(EnumSet.of(AdminPermission.SUPPORT)) : new HashSet<>())
                .build());
    }

    private MvcResult login(User u) throws Exception {
        return mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn();
    }

    private JsonNode data(MvcResult r) throws Exception {
        return json.readTree(r.getResponse().getContentAsString()).get("data");
    }

    @Test
    void anAdminLoginSetsAnHttpOnlyStrictCookieAndKeepsTheRefreshTokenOutOfTheBody() throws Exception {
        MvcResult res = login(user(UserRole.ADMIN));
        assertThat(data(res).hasNonNull("accessToken")).isTrue();
        assertThat(data(res).has("refreshToken")).isFalse();
        String header = res.getResponse().getHeaders("Set-Cookie").stream()
                .filter(h -> h.startsWith(COOKIE + "=")).findFirst().orElseThrow();
        assertThat(header).contains("HttpOnly").contains("SameSite=Strict").contains("Path=/api/auth");
    }

    @Test
    void aCustomerStillGetsTheRefreshTokenInTheBodyAndNoCookie() throws Exception {
        MvcResult res = login(user(UserRole.CUSTOMER));
        assertThat(data(res).hasNonNull("refreshToken")).isTrue();
        assertThat(res.getResponse().getCookie(COOKIE)).isNull();
    }

    @Test
    void refreshByCookieNeedsTheCsrfHeaderAndRotatesTheCookie() throws Exception {
        String first = login(user(UserRole.ADMIN)).getResponse().getCookie(COOKIE).getValue();

        // no header: refused, nothing is spent
        mvc.perform(post("/auth/refresh").cookie(new Cookie(COOKIE, first))).andExpect(status().isForbidden());

        MvcResult ok = mvc.perform(post("/auth/refresh").cookie(new Cookie(COOKIE, first))
                        .header("X-Requested-With", "aiwa-admin"))
                .andExpect(status().isOk()).andReturn();
        assertThat(data(ok).hasNonNull("accessToken")).isTrue();
        assertThat(data(ok).has("refreshToken")).isFalse();
        String second = ok.getResponse().getCookie(COOKIE).getValue();
        assertThat(second).isNotEqualTo(first);

        // single use: the spent cookie no longer works
        mvc.perform(post("/auth/refresh").cookie(new Cookie(COOKIE, first)).header("X-Requested-With", "aiwa-admin"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/auth/refresh").cookie(new Cookie(COOKIE, second)).header("X-Requested-With", "aiwa-admin"))
                .andExpect(status().isOk());
    }

    @Test
    void refreshWithoutAnyTokenIsUnauthorized() throws Exception {
        mvc.perform(post("/auth/refresh").header("X-Requested-With", "aiwa-admin")).andExpect(status().isUnauthorized());
    }

    @Test
    void aBodyRefreshTokenStillWorksForApiClients() throws Exception {
        String refresh = data(login(user(UserRole.CUSTOMER))).get("refreshToken").asText();
        MvcResult res = mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", refresh))))
                .andExpect(status().isOk()).andReturn();
        assertThat(data(res).hasNonNull("refreshToken")).isTrue();
    }

    @Test
    void logoutRevokesTheCookieTokenAndClearsIt() throws Exception {
        MvcResult login = login(user(UserRole.ADMIN));
        String refresh = login.getResponse().getCookie(COOKIE).getValue();
        String access = data(login).get("accessToken").asText();

        MvcResult out = mvc.perform(post("/auth/logout").header("Authorization", "Bearer " + access)
                        .cookie(new Cookie(COOKIE, refresh)))
                .andExpect(status().isOk()).andReturn();
        assertThat(out.getResponse().getHeaders("Set-Cookie"))
                .anyMatch(h -> h.startsWith(COOKIE + "=") && h.contains("Max-Age=0"));

        mvc.perform(post("/auth/refresh").cookie(new Cookie(COOKIE, refresh)).header("X-Requested-With", "aiwa-admin"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/auth/me").header("Authorization", "Bearer " + access)).andExpect(status().isUnauthorized());
    }
}
