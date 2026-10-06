# AIWA security audit — 6 October 2026

The reviewed code has **four confirmed Medium security defects**, plus backend dependency maintenance that needs attention. Fix the defects and validate the deployment before security sign-off. This review did not establish a Critical vulnerability, an unauthenticated account takeover, or remote code execution; that is not a guarantee that none exists.

## Scope and source

Project: `D:/AIWA PROJECT/AIWA`. Base commit: `b2d70b93399ac318d4aa7ce83533f9d6bf485827`. The working tree changed during the review as the R6 fixes and moderation-query improvements arrived. This report includes those changes; the final source capture and SHA-256 manifest identify 758 audited working-tree source/configuration inputs. The commit alone does not reproduce this state.

Reviewed backend authentication, JWT/revocation, OTP/TOTP, authorization and sensitive files; dashboard session handling and dependency exposure; mobile credentials and request ownership; production configuration, recovery scripts and CI gates. Tests and defect probes ran in a disposable copy with synthetic accounts and tokens. The auditor changed no live application source, credentials, database, cloud account or deployment. Report files are the only audit delivery to the project.

## Confirmed findings

| ID | Severity | Problem | Prerequisite and impact |
| --- | --- | --- | --- |
| SEC-01 | Medium | A healthy Redis miss can ignore a persisted access-token revocation | A previously issued token is retained and its Redis entry is lost while its database row remains. The token authenticates until expiry or another applicable account cutoff. |
| SEC-02 | Medium | Logout reports success when neither revocation store accepts the write | Redis and database revocation operations fail. After recovery, the purportedly revoked token is still valid. |
| SEC-03 | Medium | 2FA enable bypasses guessing budgets and accepts an already enabled account | A valid access token permits repeated TOTP guesses; a correct code issues a new session without a password or MFA challenge. |
| SEC-04 | Medium | An old mobile request can acquire the new account's bearer token | Account ownership changes during an asynchronous credential read. The old payload reaches the transport under the new account. |

Severity reflects the demonstrated prerequisites, rather than treating every defect as an unauthenticated attack.

### SEC-01 — Persisted revocation is ignored after cache loss

Sources: [TokenBlacklistService.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/TokenBlacklistService.java:111>), [JwtAuthFilter.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/security/JwtAuthFilter.java:39>), [Redis configuration](<D:/AIWA PROJECT/AIWA/deploy/docker-compose.prod.yml:292>).

Normal logout writes Redis and `revoked_tokens` without setting the Redis-gap marker. On a healthy Redis miss, `isBlacklisted()` checks the token's database row only when the local/shared gap deadline indicates that Redis may be missing writes. A successfully acknowledged write that later disappears does not create that marker. The ordinary access-token filter can consequently authenticate a token that `isBlacklistedStrict()` correctly rejects.

The audit probe executes the real blacklist service and JWT filter: normal blacklist writes the database row; Redis subsequently reports a miss with no gap marker; the strict check returns true, the ordinary check returns false, and the filter creates an authentication. Redis/repository responses are controlled test doubles. This proves the application branch, not an actual Redis crash.

The supplied Redis command enables AOF without overriding its default fsync policy. Redis documents that its default once-per-second policy can lose recently acknowledged writes after a disaster, so persistence alone does not establish the missing-entry invariant. This is an operational inference; no crash was induced. [Redis persistence documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/).

**Required change:** preserve authoritative revocation after cache loss. A database check on a miss, or a rigorously enforced cache-recovery epoch/rebuild strategy, must prevent accepting a persisted revoked token. Stronger AOF durability may reduce exposure but does not by itself repair the decision logic.

**Acceptance:** normally revoke an access token, lose only its cache entry, restart/restore Redis and introduce a second backend instance; every authenticated request using that token must fail while its database revocation is live. Rehearse this with real PostgreSQL and Redis as well as deterministic tests.

### SEC-02 — Logout hides failed durable revocation

Sources: [TokenBlacklistService.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/TokenBlacklistService.java:43>), [AuthServiceImpl.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/AuthServiceImpl.java:263>), [AuthController.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/controller/AuthController.java:154>).

The Redis write failure is caught. All runtime failures from the repository are also caught and described as an already-revoked token, including infrastructure failures. The service returns normally and the controller returns HTTP 200 with “Logged out successfully.” Neither the logout method nor the blacklist method has an enclosing service transaction that would independently surface the swallowed error.

The probe calls the real controller, auth service and blacklist service with failed Redis writes and failed repository operations. It observes the controller's 200 response. Once the stores are simulated as recovered, both ordinary and strict checks say the token is unrevoked. This is a direct controller test with fake stores, rather than a live HTTP/database outage drill. It demonstrates validity after recovery, not continued operation of every API during a database outage.

**Required change:** distinguish a known duplicate revocation from inability to persist it. A successful logout response must correspond to revocation that survives recovery; otherwise return an explicit failure/degraded result and retain observable diagnostics. Preserve client-side local sign-out behavior without falsely promising server revocation.

**Acceptance:** test Redis-only failure, database-only failure, both failing and subsequent recovery, for access and refresh tokens. Verify the HTTP result and replay behavior, including duplicate concurrent logout.

### SEC-03 — 2FA enrollment confirmation has an unlimited guessing path

Sources: [AuthServiceImpl.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/AuthServiceImpl.java:202>), [RedisRateLimitFilter.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/security/RedisRateLimitFilter.java:31>).

`enableTotp()` verifies a six-digit code without spending the account sign-in budget. `/auth/2fa/enable` is also absent from the filter's IP-limit table. It accepts accounts whose TOTP is already enabled and, on success, advances the account cutoff and returns a new access/refresh session.

A Spring/MockMvc probe uses an already enrolled synthetic admin with a valid access token. Twenty-four incorrect codes all return 400, without consuming the configured five-attempt account budget or returning 429. A correct code computed from the test secret then returns a new access token and an HttpOnly refresh cookie without a password, refresh token or MFA challenge. The probe does not brute-force a real secret. The risk is that a stolen short-lived access token enables unrestricted guessing and a route to a new session if a code is guessed.

**Required change:** require a current, one-time pending enrollment before confirmation; refuse ordinary re-enablement of an enrolled account. Limit code attempts per account/enrollment and add appropriate endpoint/IP controls. Counters must survive rejected-code transaction rollback. Session issuance and existing atomic TOTP-step consumption must retain their intended guarantees.

**Acceptance:** excess wrong codes are throttled even across IPs and with Redis unavailable; an enabled account cannot renew its session through this endpoint; enrollment expires/is consumed once; successful setup still invalidates earlier sessions.

### SEC-04 — Ownership is checked after a mutation can already be sent

Sources: [api_client.dart](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/core/network/api_client.dart:181>), [profile mutation](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/controller/AuthController.java:186>).

The request interceptor captures the current generation/attempt, awaits `getAccessToken()`, and attaches the returned token without checking whether that owner is still current. A delayed read can return B's newly installed credentials for a request initiated by A. A response ownership check eventually raises `SessionChangedException`, but it cannot undo a server-side mutation.

The host probe starts A's `PATCH /auth/me` with A's profile-edit payload, holds token lookup, installs B's session using the credential lock, then releases lookup. The actual ApiClient/Dio transport receives exactly one request with `Bearer B-access`, A's ownership metadata and A's payload. The caller subsequently gets the session-change exception. The backend resolves profile mutations from the authenticated user, establishing the consequence if that request reaches it. No real account was modified; the native secure-storage ordering remains a device qualification item.

**Required change:** check generation and authentication-attempt ownership immediately before dispatch, after asynchronous credential acquisition. Drop obsolete ordinary requests before transport. Preserve intentional logout/cleanup requests that explicitly name their original token. Apply the same rule to retries and uploads.

**Acceptance:** delay token reads and switch accounts/sign out/start another sign-in; an obsolete mutation produces zero transport calls and never uses the new account's token. Current-session requests and explicit original-token cleanup still work. Repeat on Android and iOS.

## Backend dependency maintenance

This is a separate exposure review, not a fifth demonstrated application exploit. The resolved versions are recorded in [the inventory](validation/resolved-backend-versions.txt).

| Component | Resolved version | Result and required follow-up |
| --- | --- | --- |
| Embedded Tomcat | 10.1.55 | Falls inside the published ranges for CVE-2026-86350 (HTTP/2), CVE-2026-76183 (WebSocket constraints) and CVE-2026-77756 (HTTP/1.0 proxy behavior). These are fixed in 10.1.60. No backend HTTP/2/AJP configuration or WebSocket endpoint was found; Caddy's client HTTP/2 support does not prove backend exposure. Patch and verify actual connector/proxy behavior. [Apache advisories](https://tomcat.apache.org/security-10.html). |
| JJWT | 0.11.5 | Below the supported security-fix versions in the project's policy. Plan a supported-version migration and regression-test token parsing/type/cutoff behavior. No specific JJWT exploit was reproduced. [JJWT security policy](https://github.com/jwtk/jjwt/security). |
| Spring Security | 6.5.11 | Matches the version range for CVE-2026-41707, which concerns DPoP. AIWA's reviewed auth path does not use DPoP; this is not a confirmed AIWA authentication bypass. The 6.5.12 fix is enterprise-only in the advisory; assess a compatible supported stack rather than assume an OSS patch is available. [Spring advisory](https://spring.io/security/cve-2026-41707/). |

The fresh public npm production-dependency check reports **zero advisories for the dashboard**. It does not cover Maven, Dart, container images or the host OS. No complete fresh NVD/backend scan or image/Dart advisory scan was completed. CI can skip the backend scan when its API key is missing; verify actual execution and set the documented production `REQUIRE_CVE_SCAN` gate.

## Latest fixes and useful controls

| Earlier finding | Current local result | Remaining deployment evidence |
| --- | --- | --- |
| R6-01 recovery retry restarted an inconsistent pair | Updated restore harness passes 93 assertions, including failed safety-copy retry leaving the backend stopped. | Real containers, database/uploads, encrypted artifact and filesystem-permission rehearsal. |
| R6-02 stale 423/403 event ended the new mobile session | Twelve session-event ownership regressions pass within the focused run. The original event scenario is locally fixed. SEC-04 covers a different, earlier stage of request dispatch. | Android/iOS native storage and router checks. |
| R6-03 zero-match SOS search hid the global oldest alert | Latest dashboard suite passes, including the new oldest-banner tests. | Real browser and staging-data check. |

The reviewed controls include access/refresh/MFA token-type separation; account status/cutoff reload; atomic refresh/MFA-token and TOTP-step claims; protected admin roles and required admin MFA; resource ownership checks; registered-path/normalized-root checks for private documents; file decoding limits and encrypted private/TOTP storage; dashboard memory access tokens and HttpOnly refresh cookies; release configuration guards and restricted container networking. The latest moderation batch queries retain the Support authorization requirement and derive target IDs from the paged moderation results. Focused tests exercise several of these controls. This list is source/test evidence, not complete deployment certification.

The tracked-file credential pattern scan checked 802 text files. Two private-key-marker hits are parser text and a runtime-generated test key, not embedded credentials. No sensitive tracked filename was found among the checked patterns; expected environment/key files are ignored. Entropy analysis, full Git history and untracked deployment-secret contents were not scanned.

## Validation and limits

Detailed commands, scope and logs are in [validation/README.md](validation/README.md). The final backend run and latest-source moderation checks are recorded there with their actual results.

- Dashboard: all **236 tests / 34 files pass**, production build passes; fresh npm production audit reports zero.
- Flutter: analyzer passes; **37 focused tests pass**, comprising the audit probe and 36 existing/current regressions. The full Flutter attempt reached 230 passing progress entries, then stopped producing output; only the audit's process was terminated. Full-suite completion is **not established** by this review.
- Restore: **93 assertions pass** using fake Docker/database operations; NTFS permission-mode checks are skipped by the harness.
- Backend: **114 targeted tests pass** (111 existing security regressions plus three defect probes). The five moderation source/test changes arriving afterward are separately reviewed; **14 latest-source RBAC/privacy/query tests pass**, overlapping earlier regressions. Tests use H2/in-memory Redis or controlled mocks, not real PostgreSQL/Redis fault injection.

Docker's server was unavailable in this environment; PostgreSQL CLI and promtool were not available. No staging penetration test, native-device test, real-cookie browser check, full load test, cloud/IAM inspection or actual CI deployment was performed. The launch record currently has **48 unsigned gates**; test success does not close those owner/evidence decisions. [Launch sign-off](<D:/AIWA PROJECT/AIWA/docs/launch-signoff.md>).

Prioritize SEC-03 and SEC-04, then enforce durable revocation for SEC-01/SEC-02. Complete the dependency patch/reachability review, convert the included defect probes into desired-behavior regression tests, and record deployment evidence before security sign-off.
