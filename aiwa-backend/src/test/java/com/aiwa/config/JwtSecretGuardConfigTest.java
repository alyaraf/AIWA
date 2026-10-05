package com.aiwa.config;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * The default JWT secret must never be allowed to boot outside local/test —
 * regardless of *which* other profile is active, or whether one was set at
 * all (a forgotten --spring.profiles.active=prod flag falls back to Spring's
 * "default" profile, which this guard also covers).
 */
class JwtSecretGuardConfigTest {

    private JwtSecretGuardConfig guardWith(String secret, String profile) {
        JwtSecretGuardConfig guard = new JwtSecretGuardConfig();
        ReflectionTestUtils.setField(guard, "jwtSecret", secret);
        ReflectionTestUtils.setField(guard, "activeProfile", profile);
        return guard;
    }

    @Test
    void refusesToStartWithTheDefaultSecret() {
        assertThatThrownBy(() -> guardWith("aiwa-super-secret-key-change-in-production-2024", "prod")
                .validateJwtSecret())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET");
    }

    @Test
    void refusesEvenWithNoProfileSetAtAll() {
        // The exact scenario this guard exists for: someone forgets
        // --spring.profiles.active=prod and the app would otherwise boot
        // with the well-known default secret on Spring's "default" profile.
        assertThatThrownBy(() -> guardWith("aiwa-super-secret-key-change-in-production-2024", "default")
                .validateJwtSecret())
                .isInstanceOf(IllegalStateException.class);
    }


    @Test
    void aShortJwtSecretIsRefusedAtStartup() {
        assertThatThrownBy(() -> guardWith("too-short", "prod").validateJwtSecret())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("32 bytes");
    }
    @Test
    void startsFineWithARealSecretConfigured() {
        assertThatCode(() -> guardWith("a-long-random-production-secret-value", "prod").validateJwtSecret())
                .doesNotThrowAnyException();
    }
}
