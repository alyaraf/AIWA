package com.aiwa.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.function.UnaryOperator;

/**
 * Refuses to start a server whose settings are not production-safe. It runs on every profile except
 * {@code local} and {@code test}, not just {@code prod}: the dev defaults in application.yml
 * (schema {@code ddl-auto: update}, public Swagger, log-only SMS/email/push) must never be what a
 * real server runs with, and the commonest way to get there is a manual deploy that sets
 * JWT_SECRET but forgets {@code SPRING_PROFILES_ACTIVE=prod} ({@link JwtSecretGuardConfig} alone
 * would let that through).
 *
 * <p>All problems are collected and reported together, so an operator fixes them in one pass.
 * {@code AIWA_ALLOW_NON_PROD_SERVER=true} lets a deliberate non-prod profile (a named staging
 * profile, say) skip only the "profile must be prod" rule; every other check still applies.
 */
@Slf4j
@Configuration
@Profile("!local & !test")
public class ProductionGuardConfig {

    private final Environment env;
    /** Where the encryption keys are read from: the process environment, exactly like the ciphers that use them. */
    private final UnaryOperator<String> secretEnv;

    @Autowired
    public ProductionGuardConfig(Environment env) {
        this(env, System::getenv);
    }

    ProductionGuardConfig(Environment env, UnaryOperator<String> secretEnv) {
        this.env = env;
        this.secretEnv = secretEnv;
    }

    @PostConstruct
    public void validateProductionSettings() {
        List<String> problems = new ArrayList<>();

        String profiles = String.join(",", env.getActiveProfiles());
        boolean prod = Arrays.asList(env.getActiveProfiles()).contains("prod");
        if (!prod && !env.getProperty("aiwa.allow-non-prod-server", Boolean.class, false)) {
            problems.add("Spring profile 'prod' is not active (active: '" + (profiles.isBlank() ? "default" : profiles)
                    + "'): set SPRING_PROFILES_ACTIVE=prod, or AIWA_ALLOW_NON_PROD_SERVER=true for a deliberate non-prod server");
        }

        if (!"validate".equalsIgnoreCase(env.getProperty("spring.jpa.hibernate.ddl-auto", "none"))) {
            problems.add("spring.jpa.hibernate.ddl-auto must be 'validate' (JPA_DDL_AUTO=validate); schema changes go through Flyway");
        }
        if (isEnabled("springdoc.api-docs.enabled") || isEnabled("springdoc.swagger-ui.enabled")) {
            problems.add("Swagger/OpenAPI must be disabled (springdoc.api-docs.enabled=false, springdoc.swagger-ui.enabled=false)");
        }

        String smsProvider = prop("aiwa.sms.provider");
        if (smsProvider.isEmpty() || "dev-log".equalsIgnoreCase(smsProvider)) {
            problems.add("SMS_PROVIDER must not be dev-log");
        }
        if ("external".equalsIgnoreCase(smsProvider)) {
            if (prop("aiwa.sms.api-url").isEmpty()) problems.add("SMS_API_URL must be configured when SMS_PROVIDER=external");
            // R2-14: without the key every send fails at send time (sign-up codes, SOS).
            if (prop("aiwa.sms.api-key").isEmpty()) problems.add("SMS_API_KEY must be configured when SMS_PROVIDER=external");
        }

        String pushProvider = prop("aiwa.push.provider");
        if (pushProvider.isEmpty() || "dev-log".equalsIgnoreCase(pushProvider)) {
            problems.add("PUSH_PROVIDER must not be dev-log — devices will never be notified");
        }
        if ("fcm".equalsIgnoreCase(pushProvider)) {
            String creds = prop("aiwa.push.fcm-credentials-file");
            if (creds.isEmpty()) {
                problems.add("GOOGLE_APPLICATION_CREDENTIALS must point to the Firebase service-account JSON when PUSH_PROVIDER=fcm");
            } else if (!Files.isReadable(Path.of(creds))) {
                problems.add("GOOGLE_APPLICATION_CREDENTIALS file is not readable: " + creds);
            }
        }

        // R2-14: dev-log only writes each email, sign-up code included, to the log.
        String emailProvider = prop("aiwa.email.provider");
        if (emailProvider.isEmpty() || "dev-log".equalsIgnoreCase(emailProvider)) {
            problems.add("EMAIL_PROVIDER must not be dev-log — codes would only go to the log");
        }
        if ("http".equalsIgnoreCase(emailProvider)) {
            if (prop("aiwa.email.api-url").isEmpty()) problems.add("EMAIL_API_URL must be configured when EMAIL_PROVIDER=http");
            if (prop("aiwa.email.api-key").isEmpty()) problems.add("EMAIL_API_KEY must be configured when EMAIL_PROVIDER=http");
        }

        // Without it an SOS only reaches admins in the app — nobody is texted.
        if (prop("aiwa.safety.oncall-phones").isEmpty()) {
            problems.add("SAFETY_ONCALL_PHONES must list at least one on-call number");
        }

        // S-02: sensitive data must never be stored in the clear. (The backup key is checked where the
        // backup runs: deploy/docker-compose.prod.yml and deploy/backup/backup.sh.)
        requireKey(problems, "TOTP_ENCRYPTION_KEY", "admin 2FA secrets");
        requireKey(problems, "DOCUMENT_ENCRYPTION_KEY", "ID documents and selfies");

        if (!problems.isEmpty()) {
            throw new IllegalStateException("Refusing to start: this server is not production-safe ("
                    + problems.size() + " problem" + (problems.size() == 1 ? "" : "s") + "):\n - "
                    + String.join("\n - ", problems));
        }

        log.info("Production guard passed: profiles=[{}] sms={} email={} push={}",
                profiles, smsProvider, emailProvider, pushProvider);
    }

    private String prop(String key) {
        String v = env.getProperty(key);
        return v == null ? "" : v.trim();
    }

    private boolean isEnabled(String key) {
        // Springdoc is on unless explicitly switched off.
        return env.getProperty(key, Boolean.class, true);
    }

    private void requireKey(List<String> problems, String name, String protects) {
        String raw = secretEnv.apply(name);
        String value = raw == null ? "" : raw.trim();
        if (value.isEmpty()) {
            problems.add(name + " is required (" + protects + " would be stored unencrypted); see deploy/.env.example");
            return;
        }
        try {
            if (Base64.getDecoder().decode(value).length != 32) {
                problems.add(name + " must be 32 bytes, base64-encoded (openssl rand -base64 32)");
            }
        } catch (IllegalArgumentException e) {
            problems.add(name + " must be 32 bytes, base64-encoded (openssl rand -base64 32)");
        }
    }
}
