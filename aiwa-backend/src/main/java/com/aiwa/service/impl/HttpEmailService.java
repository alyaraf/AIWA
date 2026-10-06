package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.service.EmailService;
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

import java.time.Duration;
import java.util.Map;

/**
 * Email through a JSON HTTP gateway: POST {@code aiwa.email.api-url} with
 * {@code Authorization: Bearer <api-key>} and body {@code {from,to,subject,text}}.
 * That shape is accepted directly by several transactional-mail APIs and is easy
 * to put behind a small relay for the rest.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.email.provider", havingValue = "http")
public class HttpEmailService implements EmailService {

    private final RestTemplate restTemplate;

    @Value("${aiwa.email.api-url:}")
    private String apiUrl;

    @Value("${aiwa.email.api-key:}")
    private String apiKey;

    /** Optional dotted JSON path of the provider's message receipt; when set, a 2xx without it is not "accepted". */
    @Value("${aiwa.email.receipt-field:}")
    private String receiptField;

    @Value("${aiwa.email.from:no-reply@aiwa.app}")
    private String from;

    public HttpEmailService(RestTemplateBuilder builder) {
        this.restTemplate = builder
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Override
    public void send(String to, String subject, String text) {
        if (apiUrl == null || apiUrl.isBlank() || apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("Email provider is not configured");
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey);
        org.springframework.http.ResponseEntity<String> response;
        try {
            response = restTemplate.postForEntity(apiUrl,
                    new HttpEntity<>(Map.of("from", from, "to", to, "subject", subject, "text", text), headers),
                    String.class);
        } catch (RestClientException e) {
            log.error("Email gateway error: {}", com.aiwa.util.LogSafe.scrub(e.getMessage()));
            throw new BusinessException("otp.error.send_failed");
        }
        // P-07: some gateways answer 200 and report the refusal in the body.
        String refusal = GatewayRefusal.of(response.getBody(), receiptField);
        if (refusal != null) {
            log.error("Email gateway refused the message: {}", com.aiwa.util.LogSafe.scrub(refusal));
            throw new BusinessException("otp.error.send_failed");
        }
    }
}
