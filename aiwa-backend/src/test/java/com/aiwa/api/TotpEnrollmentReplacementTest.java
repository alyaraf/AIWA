package com.aiwa.api;

import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
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
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;

/**
 * A24-02: every 2FA enrollment has its own identity, and attempts, cancellation and completion are bound to it. A request
 * read from setup A must not complete, spend the budget of or cancel setup B that replaced it. Deterministic interleavings
 * against the real auth service and repository (replaces the audit's TotpReplacementAuditTest defect probe).
 */
@SpringBootTest(properties = {"aiwa.auth.totp-enroll-max-attempts=5"})
@ActiveProfiles("test")
class TotpEnrollmentReplacementTest {
    @TestConfiguration
    static class Config {
        @Bean @Primary RedisRuntimeService inMemoryRedis() {
            return new InMemoryRedisRuntimeService();
        }
    }

    @Autowired UserRepository users;
    @Autowired AuthServiceImpl auth;
    @SpyBean TotpService totp;

    private User account(boolean enabled, String confirmedSecret, String pendingSecret, String enrollmentId) {
        return users.saveAndFlush(User.builder()
                .fullName("Enrollment replacement").email("enr-repl-" + UUID.randomUUID() + "@test.aiwa")
                .phone(TestPhones.next()).password("unused-test-password")
                .role(UserRole.CUSTOMER).active(true).termsAccepted(true)
                .totpEnabled(enabled).totpSecret(confirmedSecret).totpPendingSecret(pendingSecret)
                .totpEnrollmentId(enrollmentId)
                .totpEnrollmentExpiresAt(pendingSecret == null ? null : Instant.now().plusSeconds(600)).build());
    }

    private String codeFor(String secret) {
        long step = System.currentTimeMillis() / 1000 / TotpService.stepSeconds();
        byte[] key = ReflectionTestUtils.invokeMethod(TotpService.class, "base32Decode", secret);
        return ReflectionTestUtils.invokeMethod(totp, "generateCode", key, step);
    }

    private String wrongCode(String secret) {
        for (int c = 0; ; c++) {
            String code = String.format("%06d", c);
            if (!totp.verifyCode(secret, code)) return code;
        }
    }

    /** Setup B commits (secret, identity, fresh budget) while another request is in flight. */
    private void startReplacement(User account, String secret, String enrollmentId) {
        assertThat(users.openTotpEnrollment(account.getId(), secret, enrollmentId, Instant.now().plusSeconds(600))).isEqualTo(1);
    }

    private void assertPendingEnrollment(Long id, String secret, String enrollmentId, int attempts) {
        User now = users.findById(id).orElseThrow();
        assertThat(now.getTotpPendingSecret()).isEqualTo(secret);
        assertThat(now.getTotpEnrollmentId()).isEqualTo(enrollmentId);
        assertThat(now.getTotpEnrollmentAttempts()).isEqualTo(attempts);
        assertThat(now.getTotpEnrollmentExpiresAt()).isAfter(Instant.now());
    }

    @Test
    void aValidCodeForAReplacedEnrollmentIsRefusedAndTheReplacementStaysPending() {
        String a = totp.generateSecret(), b = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        String code = codeFor(a);
        doAnswer(call -> {
            Long matched = (Long) call.callRealMethod();
            assertThat(matched).isNotNull();
            startReplacement(u, b, "enr-B"); // setup B commits after enable(A) validated A's code
            return matched;
        }).when(totp).matchingStep(eq(a), eq(code));

        assertThatThrownBy(() -> auth.enableTotp(u.getEmail(), code))
                .isInstanceOf(BusinessException.class).hasMessageContaining("totp_enrollment_expired");

        User now = users.findById(u.getId()).orElseThrow();
        assertThat(now.isTotpEnabled()).isFalse();
        assertThat(now.getTotpSecret()).isNull();
        // B is untouched: still pending with its own full budget (A spent one attempt of A's budget only).
        assertPendingEnrollment(u.getId(), b, "enr-B", 0);
        assertThat(now.getTokensValidAfter()).isNull();
        assertThat(now.getTotpLastUsedStep()).isNull();
    }

    @Test
    void theReplacementCanStillBeConfirmedAfterTheStaleRequestFailed() {
        String a = totp.generateSecret(), b = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        String codeA = codeFor(a);
        doAnswer(call -> {
            Long matched = (Long) call.callRealMethod();
            startReplacement(u, b, "enr-B");
            return matched;
        }).when(totp).matchingStep(eq(a), eq(codeA));
        assertThatThrownBy(() -> auth.enableTotp(u.getEmail(), codeA)).isInstanceOf(BusinessException.class);

        var response = auth.enableTotp(u.getEmail(), codeFor(b));

        assertThat(response.getAccessToken()).isNotBlank();
        User now = users.findById(u.getId()).orElseThrow();
        assertThat(now.isTotpEnabled()).isTrue();
        assertThat(now.getTotpSecret()).isEqualTo(b);
        assertThat(now.getTotpPendingSecret()).isNull();
        assertThat(now.getTotpEnrollmentId()).isNull();
    }

    @Test
    void aStaleWrongCodeDoesNotSpendTheReplacementsBudgetOrCancelIt() {
        String a = totp.generateSecret(), b = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        String wrong = wrongCode(a);
        doAnswer(call -> {
            Object result = call.callRealMethod();
            startReplacement(u, b, "enr-B");
            return result;
        }).when(totp).matchingStep(eq(a), eq(wrong));

        assertThatThrownBy(() -> auth.enableTotp(u.getEmail(), wrong))
                .isInstanceOf(BusinessException.class).hasMessageContaining("invalid_totp_code");

        assertPendingEnrollment(u.getId(), b, "enr-B", 0);
    }

    @Test
    void anObsoleteEnrollmentCannotSpendCancelOrCompleteItsReplacement() {
        String a = totp.generateSecret(), b = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        User staleSnapshot = users.findById(u.getId()).orElseThrow();
        startReplacement(u, b, "enr-B");
        Instant now = Instant.now();

        assertThat(users.claimTotpEnrollmentAttempt(u.getId(), staleSnapshot.getTotpEnrollmentId(), 5, now)).isZero();
        assertThat(users.closeTotpEnrollment(u.getId(), staleSnapshot.getTotpEnrollmentId())).isZero();
        assertThat(users.completeTotpEnrollment(u.getId(), staleSnapshot.getTotpEnrollmentId(), a, now, now)).isZero();

        assertPendingEnrollment(u.getId(), b, "enr-B", 0);
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isFalse();
    }

    @Test
    void cancellationCannotBeUndoneByTheCancelledEnrollment() {
        String a = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        assertThat(users.closeTotpEnrollment(u.getId(), "enr-A")).isEqualTo(1);

        assertThat(users.claimTotpEnrollmentAttempt(u.getId(), "enr-A", 5, Instant.now())).isZero();
        assertThat(users.completeTotpEnrollment(u.getId(), "enr-A", a, Instant.now(), Instant.now())).isZero();
        assertThatThrownBy(() -> auth.enableTotp(u.getEmail(), codeFor(a))).isInstanceOf(BusinessException.class);

        User now = users.findById(u.getId()).orElseThrow();
        assertThat(now.isTotpEnabled()).isFalse();
        assertThat(now.getTotpSecret()).isNull();
        assertThat(now.getTotpPendingSecret()).isNull();
    }

    @Test
    void aSetupWithoutAnIdentityFromBeforeTheMigrationMustBeStartedAgain() {
        String a = totp.generateSecret();
        User u = account(false, null, a, null);
        assertThatThrownBy(() -> auth.enableTotp(u.getEmail(), codeFor(a)))
                .isInstanceOf(BusinessException.class).hasMessageContaining("totp_enrollment_expired");
        assertThat(users.findById(u.getId()).orElseThrow().isTotpEnabled()).isFalse();
    }

    @Test
    void aReSetupKeepsTheConfirmedSecretAndTwoFactorOnUntilItIsConfirmed() {
        String confirmed = totp.generateSecret(), pending = totp.generateSecret();
        User u = account(true, confirmed, null, null);
        users.recordTotpStep(u.getId(), 12345L);

        startReplacement(u, pending, "enr-B");

        User now = users.findById(u.getId()).orElseThrow();
        assertThat(now.isTotpEnabled()).isTrue();
        assertThat(now.getTotpSecret()).isEqualTo(confirmed);
        assertThat(now.getTotpLastUsedStep()).isEqualTo(12345L); // the confirmed secret's replay guard is kept
        assertPendingEnrollment(u.getId(), pending, "enr-B", 0);
    }

    @Test
    void startingSetupOnAnAccountWithoutTwoFactorClearsTheStaleReplayGuard() {
        User u = account(false, null, null, null);
        users.recordTotpStep(u.getId(), 777L);
        startReplacement(u, totp.generateSecret(), "enr-X");
        assertThat(users.findById(u.getId()).orElseThrow().getTotpLastUsedStep()).isNull();
    }

    @Test
    void parallelConfirmationsOfTheSameEnrollmentIssueExactlyOneSession() throws Exception {
        String a = totp.generateSecret();
        User u = account(false, null, a, "enr-A");
        String code = codeFor(a);
        ExecutorService pool = Executors.newFixedThreadPool(4);
        try {
            CountDownLatch go = new CountDownLatch(1);
            AtomicInteger ok = new AtomicInteger();
            java.util.List<Future<?>> results = new java.util.ArrayList<>();
            for (int i = 0; i < 4; i++) {
                results.add(pool.submit(() -> {
                    go.await();
                    try {
                        auth.enableTotp(u.getEmail(), code);
                        ok.incrementAndGet();
                    } catch (BusinessException ignored) {
                        // lost the race
                    }
                    return null;
                }));
            }
            go.countDown();
            for (Future<?> f : results) f.get(30, TimeUnit.SECONDS);
            assertThat(ok.get()).isEqualTo(1);
        } finally {
            pool.shutdownNow();
        }
        User now = users.findById(u.getId()).orElseThrow();
        assertThat(now.isTotpEnabled()).isTrue();
        assertThat(now.getTotpSecret()).isEqualTo(a);
    }
}
