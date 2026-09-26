package com.aiwa.config;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * {@link ProductionGuardConfig} only runs when the app is booted with
 * {@code --spring.profiles.active=prod} — which is exactly the flag someone
 * forgets when they push this to a real server. A forgotten flag falls back to
 * Spring's "default" profile, which matches neither "prod" (guard skipped) nor
 * "local"/"test" (nothing else catches it either) — so the app would boot
 * fine with the well-known default JWT signing secret, letting anyone who
 * knows that string forge a valid admin token for any user id, no password
 * required. This guard runs on every profile except the two known-safe local
 * ones, specifically so a missing "prod" flag doesn't silently skip it.
 */
@Slf4j
@Configuration
@Profile("!local & !test")
public class JwtSecretGuardConfig {

    private static final String DEFAULT_JWT_SECRET = "aiwa-super-secret-key-change-in-production-2024";

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${spring.profiles.active:default}")
    private String activeProfile;

    @PostConstruct
    public void validateJwtSecret() {
        if (DEFAULT_JWT_SECRET.equals(jwtSecret)) {
            throw new IllegalStateException(
                    "Refusing to start with profile '" + activeProfile + "': JWT_SECRET is still the checked-in "
                    + "default. Set a long random JWT_SECRET before running outside the 'local' or 'test' profiles — "
                    + "anyone who knows the default string can forge a valid admin token.");
        }
    }
}
