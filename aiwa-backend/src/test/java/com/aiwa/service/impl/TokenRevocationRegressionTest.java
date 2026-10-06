package com.aiwa.service.impl;

import com.aiwa.dto.request.AuthRequest;
import com.aiwa.entity.RevokedToken;
import com.aiwa.exception.ServiceUnavailableException;
import com.aiwa.repository.RevokedTokenRepository;
import com.aiwa.security.AiwaUserDetails;
import com.aiwa.security.JwtAuthFilter;
import com.aiwa.security.JwtUtils;
import com.aiwa.controller.AuthController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * SEC-01 / SEC-02 (security audit 2026-10-06): the database row is the revocation. These replace the
 * audit's defect probes with assertions of the corrected behaviour, using the real JwtAuthFilter,
 * TokenBlacklistService, AuthServiceImpl and AuthController over fake Redis and database stores that can
 * be switched off independently. (No real Redis crash is induced; that stays a staging rehearsal.)
 */
class TokenRevocationRegressionTest {

    private static final String USER = "audit-user@example.invalid";

    private final Map<String, String> redisData = new ConcurrentHashMap<>();
    private final Map<String, RevokedToken> dbRows = new ConcurrentHashMap<>();
    private final AtomicBoolean redisDown = new AtomicBoolean();
    private final AtomicBoolean dbDown = new AtomicBoolean();
    /** When set, existsById waits here so two parallel logouts both see "not revoked yet". */
    private volatile CyclicBarrier existsBarrier;

    private JwtUtils jwt;
    private RedisRuntimeService redis;
    private RevokedTokenRepository repo;

    @BeforeEach
    void stores() throws Exception {
        jwt = new JwtUtils();
        ReflectionTestUtils.setField(jwt, "jwtSecret", "audit-only-test-signing-key-32-bytes-minimum");
        ReflectionTestUtils.setField(jwt, "jwtExpiration", 900_000L);
        ReflectionTestUtils.setField(jwt, "refreshExpiration", 7 * 86_400_000L);

        redis = mock(RedisRuntimeService.class);
        when(redis.exists(anyString())).thenAnswer(inv -> {
            if (redisDown.get()) throw new IllegalStateException("injected Redis unavailable");
            return redisData.containsKey(inv.<String>getArgument(0));
        });
        doAnswer(inv -> {
            if (redisDown.get()) throw new IllegalStateException("injected Redis unavailable");
            redisData.put(inv.getArgument(0), inv.getArgument(1));
            return null;
        }).when(redis).set(anyString(), anyString(), any(Duration.class));

        repo = mock(RevokedTokenRepository.class);
        when(repo.existsById(anyString())).thenAnswer(inv -> {
            if (dbDown.get()) throw new DataAccessResourceFailureException("injected DB unavailable");
            boolean present = dbRows.containsKey(inv.<String>getArgument(0));
            CyclicBarrier barrier = existsBarrier;
            if (barrier != null && !present) {
                try { barrier.await(5, TimeUnit.SECONDS); } catch (Exception ignored) { }
            }
            return present;
        });
        when(repo.saveAndFlush(any(RevokedToken.class))).thenAnswer(inv -> {
            if (dbDown.get()) throw new DataAccessResourceFailureException("injected DB unavailable");
            RevokedToken row = inv.getArgument(0);
            if (dbRows.putIfAbsent(row.getTokenHash(), row) != null) {
                throw new DataIntegrityViolationException("duplicate key");
            }
            return row;
        });
    }

    private TokenBlacklistService newInstance() {
        return new TokenBlacklistService(redis, jwt, repo);
    }

    private AuthController controller(TokenBlacklistService service) {
        AuthServiceImpl auth = new AuthServiceImpl(null, null, null, null, jwt, null, service, null);
        AuthController controller = new AuthController(auth, null, null, null, null, jwt, null, null, null);
        ReflectionTestUtils.setField(controller, "contextPath", "/api");
        return controller;
    }

    private int logout(AuthController controller, String access, String refresh, MockHttpServletResponse response) {
        AuthRequest.Logout body = new AuthRequest.Logout();
        body.setRefreshToken(refresh);
        return controller.logout(access == null ? null : "Bearer " + access, null, null, body, response)
                .getStatusCode().value();
    }

    private boolean filterAuthenticates(TokenBlacklistService service, String token) throws Exception {
        UserDetailsService users = mock(UserDetailsService.class);
        when(users.loadUserByUsername(USER)).thenReturn(new AiwaUserDetails(17L, USER, "unused", true,
                List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER")), null));
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/auth/me");
        request.addHeader("Authorization", "Bearer " + token);
        SecurityContextHolder.clearContext();
        try {
            new JwtAuthFilter(jwt, users, service).doFilter(request, new MockHttpServletResponse(), (req, res) -> { });
            return SecurityContextHolder.getContext().getAuthentication() != null;
        } finally {
            SecurityContextHolder.clearContext();
        }
    }

    // ── SEC-01 ──────────────────────────────────────────────────────────────

    @Test
    void aDatabaseRevokedAccessTokenIsRejectedByTheRealFilterAfterTheRedisEntryDisappears() throws Exception {
        String token = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        TokenBlacklistService service = newInstance();
        assertThat(filterAuthenticates(service, token)).as("unrevoked token authenticates").isTrue();

        service.revoke(token);
        assertThat(dbRows).hasSize(1);
        assertThat(filterAuthenticates(service, token)).as("revoked, Redis entry present").isFalse();

        redisData.clear(); // healthy Redis that lost only this entry (restart, eviction, lost AOF second)
        assertThat(filterAuthenticates(service, token)).as("Redis healthy but empty").isFalse();
        assertThat(filterAuthenticates(newInstance(), token)).as("a second backend instance").isFalse();

        redisDown.set(true); // and the outage path still holds
        assertThat(filterAuthenticates(newInstance(), token)).as("Redis down").isFalse();
    }

    @Test
    void whenTheDatabaseCannotAnswerAMissTheRequestIsNotAuthenticated() throws Exception {
        String token = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        dbDown.set(true);
        assertThat(filterAuthenticates(newInstance(), token)).isFalse();
    }

    @Test
    void anotherUsersUnrevokedTokenStillAuthenticatesAfterAnEmptyRedis() throws Exception {
        TokenBlacklistService service = newInstance();
        service.revoke(jwt.generateAccessToken(USER, 17L, "CUSTOMER"));
        redisData.clear();
        assertThat(filterAuthenticates(service, jwt.generateAccessToken(USER, 17L, "CUSTOMER"))).isTrue();
    }

    // ── SEC-02 ──────────────────────────────────────────────────────────────

    @Test
    void redisFailureAloneStillLogsOutBecauseTheDatabaseRowIsDurable() throws Exception {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();
        redisDown.set(true);

        assertThat(logout(controller(service), access, refresh, new MockHttpServletResponse())).isEqualTo(200);

        redisDown.set(false); // Redis recovers empty: replay is still refused
        assertThat(service.isBlacklisted(access)).isTrue();
        assertThat(service.isBlacklistedStrict(refresh)).isTrue();
        assertThat(filterAuthenticates(service, access)).isFalse();
    }

    @Test
    void databaseFailureAloneIsReportedAsFailedLogoutNotSuccess() {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();
        dbDown.set(true);
        MockHttpServletResponse response = new MockHttpServletResponse();

        assertThatThrownBy(() -> logout(controller(service), access, refresh, response))
                .isInstanceOf(ServiceUnavailableException.class)
                .hasMessage("auth.error.logout_revocation_failed");
        // Local sign-out stays possible: the browser cookies are cleared even though the server could not revoke.
        assertThat(response.getHeaders("Set-Cookie")).hasSize(2).allMatch(c -> c.contains("Max-Age=0"));
        assertThat(dbRows).isEmpty();

        // The database recovers and Redis has lost whatever it held: nothing was durably revoked, which is
        // exactly what the 503 told the caller; a retry now succeeds and revokes for real.
        dbDown.set(false);
        redisData.clear();
        assertThat(service.isBlacklisted(access)).isFalse();
        assertThat(logout(controller(service), access, refresh, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(service.isBlacklisted(access)).isTrue();
        assertThat(service.isBlacklistedStrict(refresh)).isTrue();
    }

    @Test
    void bothStoresFailingIsReportedAndARetryAfterRecoveryRevokes() throws Exception {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();
        redisDown.set(true);
        dbDown.set(true);

        assertThatThrownBy(() -> logout(controller(service), access, refresh, new MockHttpServletResponse()))
                .isInstanceOf(ServiceUnavailableException.class);

        redisDown.set(false);
        dbDown.set(false);
        assertThat(service.isBlacklisted(access)).as("the 503 was the truth: nothing was revoked").isFalse();
        assertThat(filterAuthenticates(service, access)).isTrue();

        assertThat(logout(controller(service), access, refresh, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(filterAuthenticates(service, access)).isFalse();
        assertThat(service.isBlacklistedStrict(refresh)).isTrue();
    }

    @Test
    void anAccessTokenFailureDoesNotSkipTheRefreshTokenAndViceVersa() {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();
        // Only the refresh token's insert fails.
        doAnswer(inv -> {
            RevokedToken row = inv.getArgument(0);
            if (row.getTokenHash().equals(TokenBlacklistService.hash(refresh))) {
                throw new DataAccessResourceFailureException("injected DB unavailable");
            }
            dbRows.put(row.getTokenHash(), row);
            return row;
        }).when(repo).saveAndFlush(any(RevokedToken.class));

        assertThatThrownBy(() -> logout(controller(service), access, refresh, new MockHttpServletResponse()))
                .isInstanceOf(ServiceUnavailableException.class);
        assertThat(dbRows).containsKey(TokenBlacklistService.hash(access)).doesNotContainKey(TokenBlacklistService.hash(refresh));
    }

    @Test
    void repeatedLogoutOfAnAlreadyRevokedTokenIsIdempotent() {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();

        assertThat(logout(controller(service), access, refresh, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(logout(controller(service), access, refresh, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(dbRows).hasSize(2);
    }

    @Test
    void anUnusableTokenHasNothingToRevokeAndLogoutStillSucceeds() {
        assertThat(logout(controller(newInstance()), "not-a-jwt", null, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(logout(controller(newInstance()), null, null, new MockHttpServletResponse())).isEqualTo(200);
        assertThat(dbRows).isEmpty();
    }

    @Test
    void aSpentRefreshTokenIsAnAlreadyRevokedTokenForLogout() {
        String refresh = jwt.generateRefreshToken(USER, 17L);
        TokenBlacklistService service = newInstance();
        assertThat(service.claimStrict(refresh)).isTrue(); // rotation spent it
        assertThat(logout(controller(service), null, refresh, new MockHttpServletResponse())).isEqualTo(200);
    }

    @Test
    void concurrentDuplicateLogoutBothSucceedWithOneRow() throws Exception {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        TokenBlacklistService service = newInstance();
        existsBarrier = new CyclicBarrier(2); // both threads see "not revoked" before either inserts
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Callable<Integer> call = () -> logout(controller(service), access, null, new MockHttpServletResponse());
            Future<Integer> a = pool.submit(call);
            Future<Integer> b = pool.submit(call);
            assertThat(a.get(10, TimeUnit.SECONDS)).isEqualTo(200);
            assertThat(b.get(10, TimeUnit.SECONDS)).isEqualTo(200);
        } finally {
            existsBarrier = null;
            pool.shutdownNow();
        }
        assertThat(dbRows).hasSize(1);
        assertThat(service.isBlacklisted(access)).isTrue();
    }

    @Test
    void aDuplicateKeyErrorWithoutTheRowBeingThereIsNotMistakenForARevocation() {
        String access = jwt.generateAccessToken(USER, 17L, "CUSTOMER");
        when(repo.saveAndFlush(any(RevokedToken.class))).thenThrow(new DataIntegrityViolationException("not a duplicate"));
        assertThatThrownBy(() -> newInstance().revoke(access)).isInstanceOf(ServiceUnavailableException.class);
    }
}
