package com.aiwa.util;

import com.aiwa.entity.ProviderProfile;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** M-05: the server tells the app how far a provider got, from what is really stored. */
class ProviderOnboardingTest {

    private static User user(UserRole role) {
        return User.builder().id(1L).role(role).build();
    }

    @Test
    void aProviderWithoutAProfileHasNotStarted() {
        assertThat(ProviderOnboarding.stageOf(user(UserRole.PROVIDER), null)).isEqualTo("NO_PROFILE");
    }

    @Test
    void aProfileWithoutAllThreeDocumentsStillNeedsThem() {
        ProviderProfile p = ProviderProfile.builder().businessName("x").nationalIdFrontPath("a").selfiePath("c").build();
        assertThat(ProviderOnboarding.stageOf(user(UserRole.PROVIDER), p)).isEqualTo("NEEDS_DOCUMENTS");
        p.setNationalIdBackPath(" ");
        assertThat(ProviderOnboarding.stageOf(user(UserRole.PROVIDER), p)).isEqualTo("NEEDS_DOCUMENTS");
    }

    @Test
    void everythingUploadedIsSubmitted() {
        ProviderProfile p = ProviderProfile.builder().businessName("x").nationalIdFrontPath("a")
                .nationalIdBackPath("b").selfiePath("c").build();
        assertThat(ProviderOnboarding.stageOf(user(UserRole.PROVIDER), p)).isEqualTo("SUBMITTED");
    }

    @Test
    void nonProvidersHaveNoOnboarding() {
        assertThat(ProviderOnboarding.stageOf(user(UserRole.CUSTOMER), null)).isNull();
        assertThat(ProviderOnboarding.stageOf(user(UserRole.ADMIN), null)).isNull();
        assertThat(ProviderOnboarding.stageOf(null, null)).isNull();
    }
}
