package com.aiwa.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

import java.util.Arrays;
import java.util.List;

/**
 * P-01: {@code ProductionGuardConfig} is switched off for the {@code local} and {@code test} profiles, and
 * {@code local} also enables the demo seeder and the unauthenticated 2FA reset helper. Adding one of them next to
 * {@code prod} would therefore disable the production guard on a production server, so that mix is refused here, on
 * every profile, before anything else starts.
 */
@Configuration
public class ProfileIsolationGuard {

    private final Environment env;

    public ProfileIsolationGuard(Environment env) {
        this.env = env;
    }

    @PostConstruct
    public void rejectMixedProfiles() {
        List<String> active = Arrays.asList(env.getActiveProfiles());
        if (active.contains("prod") && (active.contains("local") || active.contains("test"))) {
            throw new IllegalStateException("Refusing to start: profile 'prod' cannot be combined with 'local' or 'test' "
                    + "(they disable the production guard and enable development-only endpoints). Active: " + active);
        }
    }
}
