package com.aiwa.service.impl;

import com.aiwa.exception.BusinessException;
import com.aiwa.service.SmsService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Posts {@code {to,sender,message}} with a Bearer key to {@code SMS_API_URL}.
 *
 * <p>Every failure throws, so callers that track delivery (SOS texts) see it:
 * a transport error, a non-2xx answer, or a 2xx whose JSON body says the
 * message was refused ({@code success:false}, {@code ok:false}, a failure
 * {@code status}, or a non-empty {@code error}). Many gateways answer 200 with
 * such a body, so a 2xx alone is not proof of delivery. Callers that want best
 * effort catch the exception themselves.
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "aiwa.sms.provider", havingValue = "external")
public class ExternalSmsService implements SmsService {

    static final String SENT_METRIC = "aiwa.sms.sent";
    private static final Set<String> FAILED_STATUSES =
            Set.of("error", "failed", "failure", "fail", "rejected", "refused", "undelivered");

    private final RestTemplate restTemplate;
    /** AU-09: sign-up and reset codes run on a request thread, so they give up much sooner than an SOS text. */
    private final RestTemplate otpRestTemplate;
    private final ObjectMapper json = new ObjectMapper();
    private MeterRegistry meterRegistry;

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
        this.otpRestTemplate = restTemplateBuilder
                .setConnectTimeout(Duration.ofSeconds(3))
                .setReadTimeout(Duration.ofSeconds(5))
                .build();
    }

    @Autowired(required = false)
    void setMeterRegistry(MeterRegistry registry) {
        this.meterRegistry = registry;
    }

    @Override
    public void sendOtp(String phone, String code, int expiresInMinutes) {
        post(otpRestTemplate, phone, "Your AIWA verification code is " + code + ". It expires in " + expiresInMinutes + " minutes.", "otp");
    }

    @Override
    public void send(String phone, String message) {
        post(restTemplate, phone, message, "text");
    }

    private void post(RestTemplate template, String phone, String message, String kind) {
        if (apiUrl == null || apiUrl.isBlank() || apiKey == null || apiKey.isBlank()) {
            count(kind, "not_configured");
            throw new BusinessException("SMS provider is not configured");
        }
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.setBearerAuth(apiKey);
        Map<String, Object> body = Map.of("to", phone, "sender", sender, "message", message);
        ResponseEntity<String> response;
        try {
            response = template.postForEntity(apiUrl, new HttpEntity<>(body, headers), String.class);
        } catch (RestClientException e) {
            count(kind, "error");
            log.error("SMS gateway error for …{}: {}", tail(phone), e.getMessage());
            throw new BusinessException("otp.error.send_failed");
        }
        String refusal = refusal(response.getBody());
        if (refusal != null) {
            count(kind, "refused");
            log.error("SMS gateway refused the text to …{}: {}", tail(phone), refusal);
            throw new BusinessException("otp.error.send_failed");
        }
        count(kind, "ok");
    }

    /** The reason a 2xx body reports a refusal, or null when it doesn't (or isn't JSON). */
    String refusal(String body) {
        if (body == null || body.isBlank()) return null;
        JsonNode root;
        try {
            root = json.readTree(body);
        } catch (Exception notJson) {
            return null;
        }
        if (root == null || !root.isObject()) return null;
        for (String flag : new String[]{"success", "ok"}) {
            JsonNode v = root.get(flag);
            if (v != null && v.isBoolean() && !v.asBoolean()) return flag + "=false" + detail(root);
        }
        JsonNode status = root.get("status");
        if (status != null && status.isTextual()
                && FAILED_STATUSES.contains(status.asText().trim().toLowerCase(Locale.ROOT))) {
            return "status=" + status.asText() + detail(root);
        }
        JsonNode error = root.get("error");
        if (error != null && !error.isNull() && !(error.isTextual() && error.asText().isBlank())
                && !(error.isBoolean() && !error.asBoolean())) {
            return "error=" + truncate(error.toString());
        }
        return null;
    }

    private static String detail(JsonNode root) {
        for (String key : new String[]{"message", "error", "reason"}) {
            JsonNode v = root.get(key);
            if (v != null && !v.isNull()) return " (" + truncate(v.asText(v.toString())) + ")";
        }
        return "";
    }

    private static String truncate(String s) {
        return s.length() > 200 ? s.substring(0, 200) : s;
    }

    private void count(String kind, String result) {
        if (meterRegistry != null) meterRegistry.counter(SENT_METRIC, "kind", kind, "result", result).increment();
    }

    private static String tail(String phone) {
        return phone == null || phone.length() < 4 ? "?" : phone.substring(phone.length() - 4);
    }
}
