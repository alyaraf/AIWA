package com.aiwa.service.impl;

import com.aiwa.enums.DevicePlatform;
import com.aiwa.service.PushNotificationService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * Push delivery through Firebase Cloud Messaging HTTP v1
 * ({@code POST https://fcm.googleapis.com/v1/projects/{project}/messages:send}).
 *
 * <p>Google shut down the legacy {@code fcm/send} + server-key API in 2024, so
 * the previous implementation could never deliver. v1 authenticates with a
 * short-lived OAuth2 access token obtained from a Firebase service account
 * (JWT-bearer grant, RS256) — built here with the jjwt library the project
 * already ships, so no extra dependency is needed. The token is cached until a
 * minute before it expires.</p>
 *
 * <p>Configuration: {@code PUSH_PROVIDER=fcm} and
 * {@code GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json}
 * (optionally {@code FCM_PROJECT_ID}; defaults to the JSON's project_id).
 * iOS devices are reached through the same project (FCM relays to APNs).</p>
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.push.provider", havingValue = "fcm")
public class FcmPushService implements PushNotificationService {

    static final String SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
    static final String DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final PushDeviceService pushDevices;

    @Value("${aiwa.push.fcm-credentials-file:}")
    private String credentialsFile;

    @Value("${aiwa.push.fcm-project-id:}")
    private String projectIdOverride;

    private ServiceAccount account;
    private String cachedToken;
    private Instant cachedTokenExpiry = Instant.EPOCH;

    public FcmPushService(RestTemplateBuilder builder, ObjectMapper objectMapper, PushDeviceService pushDevices) {
        this.restTemplate = builder
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(10))
                .build();
        this.objectMapper = objectMapper;
        this.pushDevices = pushDevices;
    }

    record ServiceAccount(String projectId, String clientEmail, PrivateKey privateKey, String tokenUri) {}

    @Override
    public void send(String deviceToken, DevicePlatform platform, String title, String body, Map<String, String> data) {
        if (deviceToken == null || deviceToken.isBlank()) return;
        ServiceAccount sa;
        String accessToken;
        try {
            sa = account();
            accessToken = accessToken(sa);
        } catch (RuntimeException | IOException e) {
            log.error("Push not sent — FCM credentials unusable: {}", com.aiwa.util.LogSafe.scrub(e.getMessage()));
            count("credentials");
            return;
        }

        Map<String, Object> message = new HashMap<>();
        message.put("token", deviceToken);
        message.put("notification", Map.of("title", title != null ? title : "", "body", body != null ? body : ""));
        // FCM v1 requires every data value to be a string.
        Map<String, String> safeData = new HashMap<>();
        if (data != null) data.forEach((k, v) -> safeData.put(k, v != null ? v : ""));
        message.put("data", safeData);
        message.put("android", Map.of("priority", "HIGH"));
        message.put("apns", Map.of("headers", Map.of("apns-priority", "10")));

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(accessToken);
        String url = "https://fcm.googleapis.com/v1/projects/" + sa.projectId() + "/messages:send";
        try {
            restTemplate.postForEntity(url, new HttpEntity<>(Map.of("message", message), headers), String.class);
            count("ok");
        } catch (HttpClientErrorException e) {
            String err = e.getResponseBodyAsString();
            int status = e.getStatusCode().value();
            if (status == 404 || err.contains("UNREGISTERED")
                    || (status == 400 && err.contains("registration token"))) {
                // The app was uninstalled or the token rotated — stop pushing to it.
                clearToken(deviceToken);
            } else if (status == 401) {
                invalidateAccessToken();
            }
            log.warn("FCM rejected push to token {}…: {}", head(deviceToken), e.getStatusCode());
            count(status == 404 || err.contains("UNREGISTERED") ? "unregistered" : "rejected");
        } catch (RestClientException e) {
            // A push failure must never break the caller — the in-app notification
            // was already recorded; this is only the best-effort real-time nudge.
            log.warn("FCM push failed for token {}…: {}", head(deviceToken), com.aiwa.util.LogSafe.scrub(e.getMessage()));
            count("error");
        }
    }

    private io.micrometer.core.instrument.MeterRegistry meterRegistry;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMeterRegistry(io.micrometer.core.instrument.MeterRegistry registry) {
        this.meterRegistry = registry;
    }

    /** AU-11: aiwa.push.sent{result} — ok, unregistered, rejected, error, credentials. */
    private void count(String result) {
        if (meterRegistry != null) meterRegistry.counter("aiwa.push.sent", "result", result).increment();
    }

    void clearToken(String deviceToken) {
        try {
            pushDevices.forget(deviceToken);
        } catch (RuntimeException e) {
            log.warn("Could not clear a dead push token: {}", com.aiwa.util.LogSafe.scrub(e.getMessage()));
        }
    }

    private synchronized void invalidateAccessToken() {
        cachedToken = null;
        cachedTokenExpiry = Instant.EPOCH;
    }

    private synchronized ServiceAccount account() throws IOException {
        if (account == null) {
            if (credentialsFile == null || credentialsFile.isBlank()) {
                throw new IllegalStateException("GOOGLE_APPLICATION_CREDENTIALS is not set");
            }
            account = parseServiceAccount(Files.readString(Path.of(credentialsFile)), projectIdOverride, objectMapper);
        }
        return account;
    }

    static ServiceAccount parseServiceAccount(String json, String projectIdOverride, ObjectMapper mapper)
            throws IOException {
        JsonNode node = mapper.readTree(json);
        String clientEmail = node.path("client_email").asText(null);
        String pem = node.path("private_key").asText(null);
        String projectId = projectIdOverride != null && !projectIdOverride.isBlank()
                ? projectIdOverride : node.path("project_id").asText(null);
        String tokenUri = node.path("token_uri").asText(DEFAULT_TOKEN_URI);
        if (clientEmail == null || pem == null || projectId == null) {
            throw new IllegalStateException("service-account JSON lacks client_email, private_key or project_id");
        }
        return new ServiceAccount(projectId, clientEmail, parsePkcs8(pem), tokenUri);
    }

    static PrivateKey parsePkcs8(String pem) {
        try {
            String base64 = pem.replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");
            byte[] der = Base64.getDecoder().decode(base64);
            return KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(der));
        } catch (Exception e) {
            throw new IllegalStateException("private_key is not a PKCS#8 RSA key", e);
        }
    }

    /** Signed JWT-bearer assertion for Google's OAuth2 token endpoint. */
    static String buildAssertion(ServiceAccount sa, Instant now) {
        return Jwts.builder()
                .issuer(sa.clientEmail())
                .audience().add(sa.tokenUri()).and()
                .claim("scope", SCOPE)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(3600)))
                .signWith(sa.privateKey(), Jwts.SIG.RS256)
                .compact();
    }

    private synchronized String accessToken(ServiceAccount sa) {
        Instant now = Instant.now();
        if (cachedToken != null && now.isBefore(cachedTokenExpiry)) return cachedToken;

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
        form.add("assertion", buildAssertion(sa, now));
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        ResponseEntity<JsonNode> res = restTemplate.postForEntity(sa.tokenUri(), new HttpEntity<>(form, headers),
                JsonNode.class);
        JsonNode body = res.getBody();
        if (body == null || !body.hasNonNull("access_token")) {
            throw new IllegalStateException("OAuth token response had no access_token");
        }
        cachedToken = body.get("access_token").asText();
        long expiresIn = body.path("expires_in").asLong(3600);
        cachedTokenExpiry = now.plusSeconds(Math.max(60, expiresIn - 60));
        return cachedToken;
    }

    /** Enough of a push token to tell devices apart in the logs. CodeQL accepts substring(0, n<=7) as masking. */
    static String head(String token) {
        return token != null && token.length() > 6 ? token.substring(0, 6) : "";
    }
}
