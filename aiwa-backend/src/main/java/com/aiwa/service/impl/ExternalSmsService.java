package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.service.SmsService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "aiwa.sms.provider", havingValue = "external")
public class ExternalSmsService implements SmsService {

    private final RestTemplateBuilder restTemplateBuilder;

    @Value("${aiwa.sms.api-url:}")
    private String apiUrl;

    @Value("${aiwa.sms.api-key:}")
    private String apiKey;

    @Value("${aiwa.sms.sender:AIWA}")
    private String sender;

    @Override
    public void sendOtp(String phone, String code, int expiresInMinutes) {
        if (apiUrl == null || apiUrl.isBlank() || apiKey == null || apiKey.isBlank()) {
            throw new BusinessException("SMS provider is not configured");
        }

        RestTemplate restTemplate = restTemplateBuilder.build();
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey);

        Map<String, Object> body = Map.of(
                "to", phone,
                "sender", sender,
                "message", "Your AIWA verification code is " + code + ". It expires in " + expiresInMinutes + " minutes."
        );

        restTemplate.postForEntity(apiUrl, new HttpEntity<>(body, headers), String.class);
    }
}
