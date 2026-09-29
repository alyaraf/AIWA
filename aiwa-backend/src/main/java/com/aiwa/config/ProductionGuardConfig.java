package com.aiwa.config;

import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import java.nio.file.Files;
import java.nio.file.Path;

@Configuration
@Profile("prod")
@RequiredArgsConstructor
public class ProductionGuardConfig {

    // The JWT secret check lives in JwtSecretGuardConfig — it runs on every
    // profile except local/test, not just "prod", so a forgotten
    // --spring.profiles.active=prod flag can't skip it. These checks are
    // operational (notifications working, not a security boundary), so
    // staying prod-only here is fine.

    @Value("${aiwa.sms.provider}")
    private String smsProvider;

    @Value("${aiwa.sms.api-url:}")
    private String smsApiUrl;

    @Value("${aiwa.push.provider:dev-log}")
    private String pushProvider;

    @Value("${aiwa.push.fcm-credentials-file:}")
    private String fcmCredentialsFile;

    @Value("${aiwa.email.provider:dev-log}")
    private String emailProvider;

    @Value("${aiwa.email.api-url:}")
    private String emailApiUrl;

    @PostConstruct
    public void validateProductionSettings() {
        if ("dev-log".equalsIgnoreCase(smsProvider)) {
            throw new IllegalStateException("SMS_PROVIDER must not be dev-log in prod");
        }
        if ("external".equalsIgnoreCase(smsProvider) && (smsApiUrl == null || smsApiUrl.isBlank())) {
            throw new IllegalStateException("SMS_API_URL must be configured when SMS_PROVIDER=external");
        }
        if ("dev-log".equalsIgnoreCase(pushProvider)) {
            throw new IllegalStateException("PUSH_PROVIDER must not be dev-log in prod — devices will never be notified");
        }
        if ("fcm".equalsIgnoreCase(pushProvider)) {
            if (fcmCredentialsFile == null || fcmCredentialsFile.isBlank()) {
                throw new IllegalStateException(
                        "GOOGLE_APPLICATION_CREDENTIALS must point to the Firebase service-account JSON when PUSH_PROVIDER=fcm");
            }
            if (!Files.isReadable(Path.of(fcmCredentialsFile))) {
                throw new IllegalStateException("GOOGLE_APPLICATION_CREDENTIALS file is not readable: " + fcmCredentialsFile);
            }
        }
        if ("http".equalsIgnoreCase(emailProvider) && (emailApiUrl == null || emailApiUrl.isBlank())) {
            throw new IllegalStateException("EMAIL_API_URL must be configured when EMAIL_PROVIDER=http");
        }
    }
}
