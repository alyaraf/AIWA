package com.aiwa.service.impl;

import com.aiwa.enums.DevicePlatform;
import com.aiwa.service.PushNotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

/**
 * Real push delivery via Firebase Cloud Messaging's legacy HTTP API
 * ({@code fcm/send} + a server key). This is enough to actually reach a
 * device — which is the piece that was missing entirely — but Google has
 * deprecated this endpoint in favor of the HTTP v1 API (OAuth2 service
 * account credentials, one endpoint per Firebase project). Swap this class
 * for an HTTP v1 client before relying on it in production; APNs-native
 * devices also go through FCM here (FCM relays to APNs) as long as the iOS
 * app is registered with the same Firebase project.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "aiwa.push.provider", havingValue = "fcm")
public class FcmPushService implements PushNotificationService {

    private static final String FCM_LEGACY_SEND_URL = "https://fcm.googleapis.com/fcm/send";

    private final RestTemplateBuilder restTemplateBuilder;

    @Value("${aiwa.push.fcm-server-key:}")
    private String serverKey;

    @Override
    public void send(String deviceToken, DevicePlatform platform, String title, String body, Map<String, String> data) {
        if (deviceToken == null || deviceToken.isBlank()) return;
        if (serverKey == null || serverKey.isBlank()) {
            log.warn("Push not sent — aiwa.push.fcm-server-key is not configured");
            return;
        }

        RestTemplate restTemplate = restTemplateBuilder.build();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "key=" + serverKey);

        Map<String, Object> notification = new HashMap<>();
        notification.put("title", title);
        notification.put("body", body);

        Map<String, Object> payload = new HashMap<>();
        payload.put("to", deviceToken);
        payload.put("notification", notification);
        payload.put("data", data != null ? data : Map.of());
        payload.put("priority", "high");

        try {
            restTemplate.postForEntity(FCM_LEGACY_SEND_URL, new HttpEntity<>(payload, headers), String.class);
        } catch (RestClientException ex) {
            // A push failure must never break the caller — the in-app notification
            // was already recorded; this is only the best-effort real-time nudge.
            log.warn("FCM push failed for token ending …{}: {}",
                    deviceToken.length() > 6 ? deviceToken.substring(deviceToken.length() - 6) : deviceToken,
                    ex.getMessage());
        }
    }
}
