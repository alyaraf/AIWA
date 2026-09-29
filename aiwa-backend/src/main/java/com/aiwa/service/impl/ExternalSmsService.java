package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.service.SmsService;
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

@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.sms.provider", havingValue = "external")
public class ExternalSmsService implements SmsService {

    private final RestTemplate restTemplate;

    @Value("${aiwa.sms.api-url:}")
    private String apiUrl;

    @Value("${aiwa.sms.api-key:}")
    private String apiKey;

    @Value("${aiwa.sms.sender:AIWA}")
    private String sender;

    public ExternalSmsService(RestTemplateBuilder restTemplateBuilder) {
        // Bounded timeouts: a hung gateway must not hold request threads forever.
        this.restTemplate = restTemplateBuilder
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Override
    public void sendOtp(String phone, String code, int expiresInMinutes) {
        post(phone, "Your AIWA verification code is " + code + ". It expires in " + expiresInMinutes + " minutes.");
    }

    @Override
    public void send(String phone, String message) {
        try {
            post(phone, message);
        } catch (RuntimeException e) {
            // Alerts are best effort per recipient; one bad number must not stop the rest.
            log.warn("SMS to …{} failed: {}", tail(phone), e.getMessage());
        }
    }

    private void post(String phone, String message) {
        if (apiUrl == null || apiUrl.isBlank() || apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("SMS provider is not configured");
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey);
        Map<String, Object> body = Map.of("to", phone, "sender", sender, "message", message);
        try {
            restTemplate.postForEntity(apiUrl, new HttpEntity<>(body, headers), String.class);
        } catch (RestClientException e) {
            log.error("SMS gateway error for …{}: {}", tail(phone), e.getMessage());
            throw new BusinessException("otp.error.send_failed");
        }
    }

    private static String tail(String phone) {
        return phone == null || phone.length() < 4 ? "?" : phone.substring(phone.length() - 4);
    }
}
