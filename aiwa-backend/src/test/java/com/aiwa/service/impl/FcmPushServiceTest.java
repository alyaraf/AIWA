package com.aiwa.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.Test;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** The FCM HTTP v1 OAuth assertion is built and RS256-signed from a service-account JSON (BE-2). */
class FcmPushServiceTest {

    @Test
    void serviceAccountJsonProducesAVerifiableAssertion() throws Exception {
        KeyPairGenerator gen = KeyPairGenerator.getInstance("RSA");
        gen.initialize(2048);
        KeyPair kp = gen.generateKeyPair();
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + Base64.getMimeEncoder(64, "\n".getBytes()).encodeToString(kp.getPrivate().getEncoded())
                + "\n-----END PRIVATE KEY-----\n";
        String json = new ObjectMapper().writeValueAsString(Map.of(
                "type", "service_account", "project_id", "aiwa-test",
                "client_email", "push@aiwa-test.iam.gserviceaccount.com", "private_key", pem,
                "token_uri", "https://oauth2.googleapis.com/token"));

        FcmPushService.ServiceAccount sa = FcmPushService.parseServiceAccount(json, "", new ObjectMapper());
        assertThat(sa.projectId()).isEqualTo("aiwa-test");

        String assertion = FcmPushService.buildAssertion(sa, Instant.now());
        Claims claims = Jwts.parser().verifyWith(kp.getPublic()).build()
                .parseSignedClaims(assertion).getPayload();
        assertThat(claims.getIssuer()).isEqualTo("push@aiwa-test.iam.gserviceaccount.com");
        assertThat(claims.getAudience()).containsExactly("https://oauth2.googleapis.com/token");
        assertThat(claims.get("scope")).isEqualTo(FcmPushService.SCOPE);
    }

    @Test
    void brokenPrivateKeysAreReportedClearly() {
        String json = "{\"project_id\":\"a\",\"client_email\":\"x@y\",\"private_key\":\"not a key\"}";
        assertThatThrownBy(() -> FcmPushService.parseServiceAccount(json, "b", new ObjectMapper()))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("PKCS#8");
    }

    /** B-08: one rejected push is one failed outcome, not two. */
    @Test
    void aRejectedPushCountsOnce() {
        io.micrometer.core.instrument.simple.SimpleMeterRegistry registry =
                new io.micrometer.core.instrument.simple.SimpleMeterRegistry();
        org.springframework.web.client.RestTemplate rest = new org.springframework.web.client.RestTemplate();
        org.springframework.test.web.client.MockRestServiceServer server =
                org.springframework.test.web.client.MockRestServiceServer.bindTo(rest).build();
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.anything())
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators
                        .withStatus(org.springframework.http.HttpStatus.FORBIDDEN).body("{\"error\":\"denied\"}"));
        FcmPushService push = new FcmPushService(new org.springframework.boot.web.client.RestTemplateBuilder(),
                new ObjectMapper(), org.mockito.Mockito.mock(PushDeviceService.class));
        org.springframework.test.util.ReflectionTestUtils.setField(push, "restTemplate", rest);
        org.springframework.test.util.ReflectionTestUtils.setField(push, "account",
                new FcmPushService.ServiceAccount("aiwa-test", "x@y", null, FcmPushService.DEFAULT_TOKEN_URI));
        org.springframework.test.util.ReflectionTestUtils.setField(push, "cachedToken", "t");
        org.springframework.test.util.ReflectionTestUtils.setField(push, "cachedTokenExpiry", Instant.now().plusSeconds(600));
        push.setMeterRegistry(registry);

        push.send("device-token-123456", com.aiwa.enums.DevicePlatform.ANDROID, "t", "b", Map.of());

        assertThat(registry.counter("aiwa.push.sent", "result", "rejected").count()).isEqualTo(1.0);
    }
}
