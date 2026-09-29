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
        Claims claims = Jwts.parserBuilder().setSigningKey(kp.getPublic()).build()
                .parseClaimsJws(assertion).getBody();
        assertThat(claims.getIssuer()).isEqualTo("push@aiwa-test.iam.gserviceaccount.com");
        assertThat(claims.getAudience()).isEqualTo("https://oauth2.googleapis.com/token");
        assertThat(claims.get("scope")).isEqualTo(FcmPushService.SCOPE);
    }

    @Test
    void brokenPrivateKeysAreReportedClearly() {
        String json = "{\"project_id\":\"a\",\"client_email\":\"x@y\",\"private_key\":\"not a key\"}";
        assertThatThrownBy(() -> FcmPushService.parseServiceAccount(json, "b", new ObjectMapper()))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("PKCS#8");
    }
}
