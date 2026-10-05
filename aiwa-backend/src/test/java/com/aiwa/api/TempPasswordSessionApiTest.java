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

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** P-06: a session that was started with a temporary password ends when that password expires. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class TempPasswordSessionApiTest {

    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() { return new InMemoryRedisRuntimeService(); }
    }

    private static final AtomicInteger SEQ = new AtomicInteger(0);
    private static final String PASSWORD = "Secret123!";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired UserRepository userRepo;
    @Autowired PasswordEncoder encoder;
    @Autowired RedisRuntimeService redis;

    @BeforeEach
    void reset() {
        ((InMemoryRedisRuntimeService) redis).clear();
    }

    private User customer() {
        int n = SEQ.incrementAndGet();
        return userRepo.save(User.builder().fullName("temp " + n).email("temp-pw" + n + "@test.aiwa")
                .phone("+2010441" + String.format("%05d", n)).password(encoder.encode(PASSWORD))
                .role(UserRole.CUSTOMER).active(true).termsAccepted(true)
                .tempPasswordExpiresAt(Instant.now().plusSeconds(3600)).build());
    }

    private JsonNode login(User u) throws Exception {
        return json.readTree(mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString()).get("data");
    }

    @Test
    void expiryEndsAnAlreadyIssuedAccessAndRefreshSession() throws Exception {
        User u = customer();
        JsonNode tokens = login(u);
        String bearer = "Bearer " + tokens.get("accessToken").asText();
        mvc.perform(get("/auth/me").header("Authorization", bearer)).andExpect(status().isOk());

        Thread.sleep(30);
        u = userRepo.findById(u.getId()).orElseThrow();
        u.setTempPasswordExpiresAt(Instant.now()); // the temporary password has now expired
        userRepo.save(u);

        mvc.perform(get("/auth/me").header("Authorization", bearer)).andExpect(status().isUnauthorized());
        mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", tokens.get("refreshToken").asText()))))
                .andExpect(status().isUnauthorized());
        // and the expired password itself no longer signs in
        mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("identifier", u.getEmail(), "password", PASSWORD))))
                .andExpect(status().is4xxClientError());
    }

    @Test
    void anAccountWithoutATemporaryPasswordIsUnaffected() throws Exception {
        User u = customer();
        u.setTempPasswordExpiresAt(null);
        userRepo.save(u);
        String bearer = "Bearer " + login(u).get("accessToken").asText();
        assertThat(userRepo.findById(u.getId()).orElseThrow().effectiveTokensValidAfter()).isNull();
        mvc.perform(get("/auth/me").header("Authorization", bearer)).andExpect(status().isOk());
    }
}
