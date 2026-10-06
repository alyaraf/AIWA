# Security audit 2026-10-06 - remediation record

Audit: [security-audit.md](security-audit.md); evidence in [validation/](validation/README.md) (kept unchanged as history).
Work is **uncommitted in the tree**. Environment: Windows, JDK 17.0.19, Maven 3.9.15, Node 20.20.2, Flutter 3.47.5, Git Bash. Docker, PostgreSQL, Redis, promtool, devices
and CI are **not available here**; nothing below ran against them. "Fixed" means closed in code with the listed tests passing, never deployed, device-, container- or CI-verified.
**This is not a production-readiness or security sign-off.** The results of each validation run are in "Validation results" at the end.

## Status

| ID | Status | Changed files | Regression tests | Closure evidence / what remains |
| --- | --- | --- | --- | --- |
| SEC-01 | **fixed** (fake Redis/DB); real PostgreSQL+Redis rehearsal open (gate 49) | `TokenBlacklistService.java` | `TokenRevocationRegressionTest` (real `JwtAuthFilter`), `TokenBlacklistServiceTest` | A Redis miss is now always settled by the database row. Revoked token rejected after Redis entry loss, with Redis down, and by a second instance. |
| SEC-02 | **fixed** (fake stores); live outage drill open (gate 49) | `TokenBlacklistService.java`, `AuthServiceImpl.java`, `AuthController.java`, i18n, dashboard `api.js`/`App.jsx`, mobile `api_client.dart` | `TokenRevocationRegressionTest`, `App.signout.test.jsx` | Logout returns 200 only when the database row is confirmed; otherwise 503 `auth.error.logout_revocation_failed`, cookies still cleared. |
| SEC-03 | **fixed** (H2 + in-memory Redis); staging check open (gate 50) | `AuthServiceImpl.java`, `User.java`, `UserRepository.java`, `RedisRateLimitFilter.java`, `V35__totp_enrollment_limits.sql`, i18n | `TotpEnrollmentApiTest`, `AdminTwoFactorEnrolmentApiTest` | One-time, expiring, attempt-limited pending enrollment; enabled accounts refused; per-IP throttle. |
| SEC-04 | **fixed** (host tests, real ApiClient/Dio); Android/iOS device evidence open (gate 51) | `api_client.dart`, `push_registrar.dart` | `test/core/request_ownership_test.dart` | Ownership re-checked after the credential read and before dispatch; obsolete requests never reach the transport. |
| Dependencies | **upgraded**; image/OS/Dart scans and connector checks open (gate 52) | `pom.xml`, `JwtUtils.java`, `FcmPushService.java` | `JwtUtilsJjwtMigrationTest`, `FcmPushServiceTest`, auth suites | Tomcat 10.1.60, JJWT 0.13.0. Spring Security 6.5.11 kept, see below. |

## SEC-01 - database settles every Redis miss

Design: before, `isBlacklisted()` consulted the database only while a "Redis gap" marker was open, so a healthy-but-empty Redis (restart, eviction, lost AOF second, a second instance's cache)
accepted a revoked token. Now: Redis hit -> revoked; otherwise (miss **or** Redis error) -> `revokedRepo.existsById(sha256(token))`. A database failure propagates; `JwtAuthFilter` catches it and the
request stays unauthenticated (fail closed). The gap-marker machinery (`REDIS_GAP_MARKER`, `recordRedisGap`, the in-memory deadlines) was removed because it is now redundant; old marker rows
in `revoked_tokens` are harmless and purged on expiry. Stronger AOF settings were not relied upon.

Performance assessment (**not measured on PostgreSQL**): every authenticated request now makes one primary-key existence query on `revoked_tokens` (a small table holding only unexpired revoked
tokens, purged by `purgeExpired`). The filter already loads the user by primary key on every request, so this adds a second indexed single-row read of the same cost class, no join and no write.
No negative cache was added on purpose: any cache of "not revoked" reintroduces a window in which another instance accepts a just-revoked token. If load tests show pressure, the sanctioned
mitigation is a short-lived negative cache keyed by token hash that is **invalidated by the revocation write on every instance** (needs a shared channel) - not done. Gate 49 asks for the k6 comparison.

## SEC-02 - logout reports only confirmed revocation

`TokenBlacklistService.revoke()` (replaces `blacklist()`): ignores tokens that are already unusable (malformed/expired); `existsById` -> already revoked (idempotent); otherwise `saveAndFlush`.
Only a duplicate-key error **whose row is then confirmed present** counts as a parallel logout; every other failure is "not durable". The Redis write is best effort and never decides the result.
If the row cannot be confirmed, `ServiceUnavailableException("auth.error.logout_revocation_failed")` is thrown **after** both tokens were attempted; the controller adds the cookie-clearing headers
and the global handler answers **503** (EN/AR messages). Matrix covered in tests, for access and refresh tokens: Redis down only -> 200 and replay refused after Redis returns empty; database down only
-> 503 and a retry after recovery revokes; both down -> 503, nothing revoked (stated truthfully), retry after recovery works; parallel duplicate logout -> both 200, one row; repeated logout -> 200.
Clients: the dashboard still signs out locally first and now shows a warning toast when the server did not confirm (`api.logout()` resolves false); the mobile `ApiClient.logout()` returns a bool
(false when unconfirmed), local sign-out is unchanged, and no UI notice was added there.

## SEC-03 - 2FA enrollment

- Migration `V35`: `users.totp_enrollment_expires_at`, `users.totp_enrollment_attempts` (columns `updatable = false`, written only by single-statement updates, like the sign-in counter).
- `POST /auth/2fa/setup` (password, plus current code if 2FA is on) opens an enrollment: new secret, 10-minute expiry (`aiwa.auth.totp-enroll-ttl`), attempts reset.
- `POST /auth/2fa/enable` refuses an account with 2FA already on (`auth.error.totp_already_enabled`), a missing or expired enrollment (`auth.error.totp_enrollment_expired`), and takes one of
  `aiwa.auth.totp-enroll-max-attempts` (5) attempts **before** looking at the code, in its own `REQUIRES_NEW` transaction (survives rollback; the method is also no longer `@Transactional`).
  Budget exhausted -> 429 and the enrollment is closed; setup (password) must be started again. The count is in the database, so it holds across IPs, instances and a Redis outage.
- Success is a guarded `UPDATE ... WHERE totp_enabled = false AND expiry > now`, so exactly one of any parallel confirmations wins; TOTP-step claiming (`claimTotpStep`) is unchanged and atomic.
  The account cutoff still ends earlier sessions; the caller gets the new pair.
- `RedisRateLimitFilter`: `/auth/2fa/enable` and `/auth/2fa/setup` limited to 10 POSTs/minute/IP (in-process fallback when Redis is down).
- Residual: someone holding only an access token can still make up to 5 guesses against a **legitimately pending** enrollment during its 10-minute window (about 15 of 1,000,000 codes accepted per window);
  they cannot start one without the password.

## SEC-04 - request ownership before dispatch

`_AuthInterceptor.onRequest`: the owner (generation + authentication attempt) is captured, a retry keeps the owner it was first sent under, the credential is read, and
`SecureStorage.owns(owner)` is checked **after the read and immediately before dispatch**; an obsolete request is rejected with `SessionChangedException` and never reaches the adapter. Applies to ordinary requests,
retries after refresh, and multipart uploads. Intentional clean-up requests carry `extra[ApiClient.ownCredentialsExtra]` (sign-out revocation, push-token removal): they skip the check, and never
receive the stored token (a logout with no explicit access token now sends none rather than borrowing the stored one). R6 event-ownership behavior is unchanged.

## Dependencies and advisories (checked 2026-10-06)

| Component | Before | After | Result |
| --- | --- | --- | --- |
| Embedded Tomcat | 10.1.55 (Boot 3.5.16 managed) | **10.1.60** via `tomcat.version` | 10.1.60 (released 2026-09-15) is the newest 10.1.x on the Apache page and fixes every 2026 entry listed through 10.1.59, including CVE-2026-86350 (header mix-up, 10.1.55-10.1.59). No newer patched version exists. AIWA's config shows no HTTP/2, AJP or WebSocket use (no websocket starter, no `server.http2`/AJP settings), so most were not reachable; the actual connector/proxy behavior stays a staging check. |
| JJWT | 0.11.5 | **0.13.0** | Only 0.12.x+ is supported for security fixes per the project policy. `JwtUtils` and `FcmPushService` moved to `Jwts.parser().verifyWith(..).parseSignedClaims`, `Jwts.SIG.*`, `.subject()/.id()/.issuedAt()/.expiration()/.audience()`; token layout, `typ`, `iatms` and expiry unchanged. `JwtUtilsJjwtMigrationTest` covers tampering, foreign key, `alg:none`, expiry, claim types. |
| Spring Security | 6.5.11 | **6.5.11 (unchanged)** | CVE-2026-41707 (DPoP proof replay) affects 6.5.0-6.5.11; the 6.5.12 fix is enterprise-only, OSS fixes are 7.0.7 / 7.1.1 which need Spring Boot 4 (not a patch-level change). **Not reachable in AIWA:** no `spring-security-oauth2-*` dependency and no DPoP configuration in `pom.xml` or source; authentication is the in-house `JwtAuthFilter`. Risk accepted and recorded; revisit when Boot 4 is adopted or an OSS 6.5.x appears. |

Scope of dependency checks: the Tomcat/Spring/JJWT facts above come from the official advisory pages and the project's own `pom.xml`/source. **No OWASP Dependency-Check/NVD scan, container-image scan (Trivy), Dart advisory scan or OS
scan was run** (no NVD key, no Docker). The dashboard npm audit is separate and does not cover Maven, Dart, images or the OS.

## Validation results

Run on 2026-10-06 in this working tree, after all changes:

| Check | Result |
| --- | --- |
| Backend, full suite (`mvn -o test`, forked JVM, `-Xmx1400m`) | **532 tests, 0 failures/errors/skips, BUILD SUCCESS.** An earlier attempt in a single in-process 512 MB JVM ran out of heap in `MigrationSchemaValidationTest` (resource failure, not an assertion; not counted). Tests use H2 and in-memory/mocked Redis, not real PostgreSQL/Redis. |
| New/changed backend tests | `TokenRevocationRegressionTest` (12), `TotpEnrollmentApiTest` (7), `JwtUtilsJjwtMigrationTest` (7), `TokenBlacklistServiceTest` (8), `AdminTwoFactorEnrolmentApiTest`, `FcmPushServiceTest`; the audit probes were converted, not copied. |
| Dashboard | **237 tests / 34 files pass** (236 baseline + the SEC-02 sign-out notice test); `npm run build` passes. No new npm audit was run this round (no dashboard dependency changed). |
| Flutter analyze | **No issues found.** |
| Flutter, full suite (`flutter test --timeout 60s`, bounded at 28 min) | **275 tests, all passed, run completed** (the audit's earlier full run had stalled; this one did not). Includes `request_ownership_test.dart` (10) and the existing R6 session-event tests. Host tests only. |
| Restore-flow harness (`deploy/restore_flow_test.sh`) | **Not re-run**: nothing under `deploy/` changed; the audit's 93-assertion result stands for the unchanged scripts. |
| Real PostgreSQL / Redis / Docker / devices / browser / CI / cloud / promtool | **Not available; not run.** Gates 49-53 and the earlier open gates stay unsigned. |
| Dependency scans | Advisory facts re-read from the official Apache, Spring and JJWT pages; **no NVD/OWASP, image, Dart or OS scan was run.** |

## Remaining before sign-off

Deploy order: Flyway V35 runs on next start (additive columns with defaults). Existing users in the middle of a 2FA setup must start setup again (their enrollment has no expiry).
Open: gates 49-53; the unchanged earlier gates (41-48 and the rest); backend CVE/image/Dart scans; confirming Tomcat 10.1.60 and JJWT 0.13.0 in the built image; latency comparison for the added revocation lookup.
Unresolved blockers: none in code; the items above need infrastructure not present here.

## Launch sign-off additions

Gates 49-53 were added to [../../launch-signoff.md](../../launch-signoff.md), all unsigned.
