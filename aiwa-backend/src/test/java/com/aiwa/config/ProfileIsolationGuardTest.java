package com.aiwa.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** P-01: prod must never be combined with the profiles that switch the production guard off. */
class ProfileIsolationGuardTest {

    private static MockEnvironment env(String... profiles) {
        MockEnvironment e = new MockEnvironment();
        e.setActiveProfiles(profiles);
        return e;
    }

    @Test
    void prodWithLocalOrTestIsRefused() {
        assertThatThrownBy(() -> new ProfileIsolationGuard(env("prod", "local")).rejectMixedProfiles())
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("cannot be combined");
        assertThatThrownBy(() -> new ProfileIsolationGuard(env("local", "prod")).rejectMixedProfiles())
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new ProfileIsolationGuard(env("prod", "test")).rejectMixedProfiles())
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void singleProfilesAndStagingAreFine() {
        assertThatCode(() -> new ProfileIsolationGuard(env("prod")).rejectMixedProfiles()).doesNotThrowAnyException();
        assertThatCode(() -> new ProfileIsolationGuard(env("local")).rejectMixedProfiles()).doesNotThrowAnyException();
        assertThatCode(() -> new ProfileIsolationGuard(env("test")).rejectMixedProfiles()).doesNotThrowAnyException();
        assertThatCode(() -> new ProfileIsolationGuard(env()).rejectMixedProfiles()).doesNotThrowAnyException();
    }
}
