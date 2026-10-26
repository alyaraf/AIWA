package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import com.aiwa.security.TotpService;
import com.aiwa.service.impl.AuthServiceImpl;
import com.aiwa.service.impl.RedisRuntimeService;
import com.aiwa.support.InMemoryRedisRuntimeService;
import com.aiwa.support.TestPhones;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;

/** Audit probe: success means the stale-enrollment defect was reproduced. */
@SpringBootTest
@ActiveProfiles("test")
class TotpReplacementAuditTest {
    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    @Autowired UserRepository users;
    @Autowired AuthServiceImpl auth;
    @SpyBean TotpService totp;

    @Test
    void replacedEnrollmentCanStillBeCompletedByTheOldCode() {
        String first = totp.generateSecret();
        String replacement = totp.generateSecret();
        User account = users.saveAndFlush(User.builder()
                .fullName("Synthetic audit account")
                .email("audit-" + UUID.randomUUID() + "@test.aiwa")
                .phone(TestPhones.next()).password("unused-test-password")
                .role(UserRole.CUSTOMER).active(true).termsAccepted(true)
                .totpEnabled(false).totpPendingSecret(first)
                .totpEnrollmentExpiresAt(Instant.now().plusSeconds(600)).build());
        long step = System.currentTimeMillis() / 1000 / TotpService.stepSeconds();
        byte[] key = ReflectionTestUtils.invokeMethod(TotpService.class, "base32Decode", first);
        String code = ReflectionTestUtils.invokeMethod(totp, "generateCode", key, step);

        doAnswer(call -> {
            Long matched = (Long) call.callRealMethod();
            assertThat(matched).isNotNull();
            // Deterministic interleaving: setup B commits after enable A read its secret.
            User restarted = users.findById(account.getId()).orElseThrow();
            restarted.setTotpPendingSecret(replacement);
            users.saveAndFlush(restarted);
            users.openTotpEnrollment(account.getId(), Instant.now().plusSeconds(600));
            assertThat(users.findById(account.getId()).orElseThrow().getTotpPendingSecret())
                    .isEqualTo(replacement);
            return matched;
        }).when(totp).matchingStep(eq(first), eq(code));

        var response = auth.enableTotp(account.getEmail(), code);
        User completed = users.findById(account.getId()).orElseThrow();
        assertThat(response.getAccessToken()).isNotBlank();
        assertThat(completed.isTotpEnabled()).isTrue();
        assertThat(completed.getTotpSecret()).isEqualTo(first);
        assertThat(completed.getTotpPendingSecret()).isNull();
        System.out.println("DEFECT REPRODUCED: old code installed secret A after setup B committed.");
    }
}
