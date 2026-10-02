package com.aiwa.config;

import com.aiwa.entity.User;
import com.aiwa.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** CR-02: the first admin is stored in the spelling sign-in looks up. */
class AdminBootstrapConfigTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final AdminBootstrapConfig bootstrap = new AdminBootstrapConfig(userRepo, encoder);

    @BeforeEach
    void noAdminYet() {
        when(userRepo.findByRoleOrderByCreatedAtDesc(any(), any())).thenReturn(Page.empty());
        when(encoder.encode(any())).thenReturn("hash");
        ReflectionTestUtils.setField(bootstrap, "adminFullName", "AIWA Admin");
        ReflectionTestUtils.setField(bootstrap, "adminPassword", "a-long-enough-password");
        ReflectionTestUtils.setField(bootstrap, "adminEmail", " Owner@AIWA.app ");
        ReflectionTestUtils.setField(bootstrap, "adminPhone", "0101 234 5678");
    }

    @Test
    void theFirstAdminIsStoredWithNormalisedEmailAndPhone() {
        bootstrap.run(null);

        ArgumentCaptor<User> saved = ArgumentCaptor.forClass(User.class);
        verify(userRepo).save(saved.capture());
        assertThat(saved.getValue().getEmail()).isEqualTo("owner@aiwa.app");
        assertThat(saved.getValue().getPhone()).isEqualTo("+201012345678");
    }

    @Test
    void bootstrapIsSkippedWhenTheNumberExistsInItsStoredSpelling() {
        when(userRepo.existsByPhone("+201012345678")).thenReturn(true);

        bootstrap.run(null);

        verify(userRepo, never()).save(any());
    }

    @Test
    void anAdminEmailThatIsNotAnEmailStopsTheBootstrap() {
        ReflectionTestUtils.setField(bootstrap, "adminEmail", "01012345678");

        assertThatThrownBy(() -> bootstrap.run(null)).hasMessageContaining("ADMIN_EMAIL");
        verify(userRepo, never()).save(any());
    }
}
