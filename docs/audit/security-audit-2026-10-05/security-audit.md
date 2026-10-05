# AIWA Security Audit - 2026-10-05

Repository: `D:\AIWA PROJECT\AIWA`

Audited commit: `410495a` on `main` (`System audit fixes SA-01 to SA-15: MFA scope, OTP receipt, restore safety, and more`).

Scope: backend auth/API/security config, admin dashboard security posture, Flutter mobile security posture, deployment/ops controls, secret exposure, and dependency audit signals available locally.

This audit is documentation/reporting only. No application code was changed.

## Executive Summary

No new confirmed critical remote-code-execution, auth-bypass, SQL injection, path traversal, or route-level IDOR was found in this pass.

The current security posture is much stronger than the stale handoff implied: many older severe issues are already fixed. The remaining highest-risk items are launch/deployment controls and least-privilege hardening rather than obvious exploitable code bugs.

Production should not launch until the High findings below are closed or explicitly waived.

## Severity Summary

| Severity | Count | Items |
| --- | ---: | --- |
| Critical | 0 | None confirmed in this pass. |
| High | 3 | Fail-closed production profile hardening, encryption-at-rest prerequisites, off-server DR/restore proof. |
| Medium | 5 | Admin token storage, broad admin read/export RBAC, tracked JVM crash log, Redis fail-open throttles, mobile release API-base guard. |
| Low | 3 | Backend CVE scan not completed, stale env/production guide drift, minor debug/test-output hygiene. |

## Remediation status (commit `30f0a66`, 2026-10-05)

| ID | Finding | Status | Notes |
| --- | --- | --- | --- |
| S-01 | Prod hardening not fail-closed | **Fixed** | `ProductionGuardConfig` runs on every profile except local/test; tests in `ProductionGuardConfigTest`. |
| S-02 | Encryption keys optional | **Fixed** | TOTP and document keys required by the backend; `BACKUP_KEY_FILE` required by compose; `backup.sh` refuses plaintext backups. |
| S-03 | Off-server backup / restore proof | **Open** | Operational gate; needs off-server sync and a restore drill. |
| S-04 | Admin tokens in localStorage | **Partly fixed** | Idle sign-out added. Cookie/BFF migration still open: `docs/admin-session-hardening.md`. |
| S-05 | Broad admin read/export RBAC | **Fixed** | Audit = SUPER_ADMIN; settlements = FINANCE; booking and analytics exports = SUPPORT or FINANCE. Regression tests in `AdminReadExportRbacApiTest`. |
| S-06 | Tracked JVM crash log | **Fixed** | File removed from git; crash/log patterns ignored. |
| S-07 | Redis fail-open throttles | **Fixed** | In-process fallback limits, metric `aiwa_ratelimit_redis_unavailable_total` and `RateLimitRedisUnavailable` alert. No route fails closed (deliberate). |
| S-08 | Mobile release API base | **Fixed, CI unverified** | Stricter Gradle/Dart check and a CI step. Flutter was not run locally; first CI run confirms. |
| S-09 | Backend CVE scan | **Wired, not yet run** | CI `dependency-scan` job; skips until the `NVD_API_KEY` secret is set. |
| S-10 | Stale env docs | **Fixed** | `.env.example`, production guide, deploy example and runbooks aligned; `ADMIN_PASSWORD` removal mandatory. |
| S-11 | Debug/test output | **Fixed** | `logDiagnostic` replaces `debugPrint`; test `println`s removed. |

Backend tests after the fixes: 399 run, 0 failures. Admin: 115 tests pass, `npm audit` clean.

## High Findings

### S-01: Production hardening is tied to `prod`; a manual deploy with a real JWT secret but missing `SPRING_PROFILES_ACTIVE=prod` can still run with dev defaults

Evidence:
- `deploy/docker-compose.prod.yml:43` correctly sets `SPRING_PROFILES_ACTIVE: prod` for the provided compose deployment.
- `aiwa-backend/src/main/resources/application.yml:13-14` defaults the Spring profile to `dev`.
- `aiwa-backend/src/main/resources/application.yml:48` defaults JPA to `ddl-auto: update`.
- `aiwa-backend/src/main/resources/application.yml:86-90` leaves SpringDoc/Swagger enabled by default.
- `aiwa-backend/src/main/resources/application.yml:191`, `198`, and `204` default SMS, email, and push providers to `dev-log`.
- `aiwa-backend/src/main/java/com/aiwa/config/ProductionGuardConfig.java:13` only loads the production guard under `@Profile("prod")`.
- `JwtSecretGuardConfig` prevents the checked-in JWT secret outside local/test, but it does not force the rest of the production profile controls once an operator supplies any custom JWT secret.

Impact: A non-compose or hand-built deployment can start with a custom JWT secret while still using dev-like behavior: schema mutation, public API docs, log-only SMS/email/push, and no prod guard enforcement for provider configuration. That can break OTP/SOS delivery, expose API maps, and create unsafe schema changes.

Recommended fix:
- Fail closed outside `local` and `test`: require either active `prod` profile or an explicit `AIWA_ALLOW_NON_PROD_SERVER=true` escape hatch.
- Move provider-delivery guards, Swagger disablement, and `ddl-auto=validate` enforcement into a guard that runs for every non-local/test profile.
- Add a startup log/health field showing active profile and provider modes.
- Add a CI smoke test that starts the app with a custom JWT secret but without `prod` and expects startup failure.

### S-02: Sensitive-at-rest encryption is optional unless operators set keys

Evidence:
- `ProductionGuardConfig.java:88-92` only warns when `TOTP_ENCRYPTION_KEY` is absent.
- `FileStorageServiceImpl.java:102-103` initializes private-file encryption from `DOCUMENT_ENCRYPTION_KEY`.
- `FileStorageServiceImpl.java:504-508` encrypts private files only when the cipher is enabled.
- `deploy/.env.example:25`, `28`, and `47` document TOTP, document, and backup encryption keys as commented/optional examples.

Impact: Admin TOTP secrets, identity documents/selfies, and backup archives can be plaintext if launch secrets are incomplete. Verification documents and admin MFA secrets are high-value data.

Recommended fix:
- Require `TOTP_ENCRYPTION_KEY`, `DOCUMENT_ENCRYPTION_KEY`, and `BACKUP_KEY_FILE` in production, or record a signed launch waiver.
- Add startup refusal for missing document encryption in `prod`.
- Add a restore drill proving encrypted backups can be restored with the stored key.

### S-03: Off-server backup and restore proof is documented but not enforced

Evidence:
- `deploy/docker-compose.prod.yml:82-83` stores PostgreSQL in a local Docker volume.
- `deploy/docker-compose.prod.yml:90-113` writes backups locally under `deploy/backups` and local upload volume.
- `docs/runbooks.md:113-123` correctly recommends nightly off-server copy, but this is not part of the compose stack or CI proof.

Impact: Server or disk loss can take out both primary data and the default local backup unless an operator separately configures off-server sync or managed database PITR.

Recommended fix:
- Make off-server sync a first-class production component or require managed PostgreSQL PITR plus external object storage for uploads.
- Track last off-server backup and last clean restore drill as release gates.
- Alert on backup heartbeat, stale local backup, and failed off-server sync.

## Medium Findings

### S-04: Admin access and refresh tokens are stored in `localStorage`

Evidence:
- `aiwa-admin-dashboard-updated/src/api.js:6-20` reads/writes admin access and refresh tokens in `window.localStorage`.
- Admin dependency audit found no current npm advisories, and no `dangerouslySetInnerHTML` sink was found, but any future XSS or malicious browser extension can read `localStorage`.

Impact: A script execution bug in the admin origin can exfiltrate refresh tokens. Admin refresh lifetime is shorter than normal users, but still long enough to matter.

Recommended fix:
- Move admin sessions to HttpOnly, Secure, SameSite cookies or a backend-for-frontend session model.
- Keep SUPER_ADMIN/FINANCE 2FA enforced and consider requiring SUPPORT 2FA too.

### S-05: Several sensitive admin read/export APIs use broad `hasRole('ADMIN')` instead of narrower permissions

Evidence:
- `AdminController.java:32-33` protects `/admin` with `hasRole('ADMIN')`; `/admin/bookings` and `/admin/bookings/export` expose booking/customer/provider/service data at lines `101-137`.
- `AuditController.java:15-16` protects audit-log list/export with `hasRole('ADMIN')`.
- `SettlementController.java:100-138` exposes settlement lists/details to any admin, while mutation routes require `Perms.FINANCE`.
- `SettlementController.java:240-241` allows any admin to export the commission ledger.
- `AnalyticsController.java:17-18` and `32-34` allow any admin to view/export analytics.

Impact: SUPPORT, FINANCE, and SUPER_ADMIN exist as separate authorities, but read/export access still often collapses to any admin. This broadens exposure of audit trails, financial data, settlement details, booking PII, and bulk CSV exports.

Recommended fix:
- Define explicit read permissions such as `PERM_AUDIT_READ`, `PERM_FINANCE_READ`, `PERM_BOOKING_MONITOR`, and `PERM_SUPPORT_READ`.
- Require FINANCE for settlement/commission exports and SUPER_ADMIN or dedicated audit permission for audit-log export.
- Add regression tests showing SUPPORT cannot export finance/audit data unless deliberately granted.

### S-06: A JVM crash log is tracked and exposes local environment details

Evidence:
- `git ls-files` shows `aiwa-backend/hs_err_pid30992.log` is tracked.
- The file includes command line, host/runtime details, username, and environment variables at `hs_err_pid30992.log:30` and `940-944`.
- No real production secret was observed in this file during this pass, but crash logs often capture environment values and process details.

Impact: Current impact is local information disclosure. If future crash logs capture deployment environment values, they can leak secrets, internal paths, tokens, or infrastructure metadata.

Recommended fix:
- Remove the crash log from version control.
- Add `hs_err_pid*.log`, `replay_pid*.log`, and general local crash/log patterns to `.gitignore`.
- If any committed crash log ever contained real secrets, rotate them and scrub history.

### S-07: Redis-backed throttles fail open for selected abuse controls

Evidence:
- `RedisRateLimitFilter.java:57-72` deliberately allows auth requests through if Redis rate-limit checks fail.
- Account-level throttles also rely on Redis and document fail-open behavior.
- OTP itself fails closed on Redis outage, and token revocation falls back to the database, so this is scoped to throttling rather than all auth state.

Impact: During Redis outages, login and account-action abuse resistance is weaker. Attackers who can trigger or coincide with Redis instability get a better brute-force/flooding window.

Recommended fix:
- Alert on rate-limit fail-open logs and Redis outage.
- Consider DB-backed fallback counters or fail-closed behavior for admin login/2FA and other high-risk endpoints.

### S-08: Mobile release builds can fall back to an HTTP emulator API base if `API_BASE_URL` is missing

Evidence:
- `Android/aiwa_app/lib/core/constants/api_constants.dart:3-7` defaults `API_BASE_URL` to `http://10.0.2.2:8080/api`.
- CI builds only a debug APK (`.github/workflows/ci.yml` Android job) and does not appear to run a release build that proves a production HTTPS `API_BASE_URL` was supplied.

Impact: A mistaken release build without the define can ship a non-production HTTP endpoint. On a real device this likely fails, but it is still a release-process security gap and can hide mistakes until late.

Recommended fix:
- Fail release builds when `API_BASE_URL` is missing or not `https://`.
- Add a CI release-build check with the staging/prod API base injected.

## Low Findings / Process Gaps

### S-09: Backend CVE scan was attempted but not completed

Evidence:
- `mvn dependency:tree` resolved successfully under JDK 17.
- OWASP Dependency-Check 12.1.8 started and downloaded plugin dependencies, but the NVD feed was only `20,000/401,169` records after multiple minutes without an NVD API key. I stopped it at 5% to avoid a long-running blocked session.

Impact: Backend dependency vulnerability status is not fully proven by this audit. The dependency versions look modern, but that is not a substitute for CVE matching.

Recommended fix:
- Add OWASP Dependency-Check, Snyk, Trivy, or GitHub Dependabot/code scanning to CI with an NVD API key or managed advisory source.
- Store the generated report artifact in CI.

### S-10: Environment examples and production guide have drift

Evidence:
- `aiwa-backend/.env.example:20` still references `FIREBASE_SERVICE_ACCOUNT_FILE`, while current code/compose uses `GOOGLE_APPLICATION_CREDENTIALS`.
- `aiwa-backend/PRODUCTION_ENVIRONMENT_GUIDE.md` still contains placeholder examples and older bootstrap language.

Impact: Operators following stale docs can misconfigure push delivery or leave bootstrap secrets around longer than intended.

Recommended fix:
- Keep only one production environment guide, aligned with `deploy/.env.example` and compose.
- Explicitly require removing `ADMIN_PASSWORD` after first bootstrap.

### S-11: Minor debug/test-output hygiene remains

Evidence:
- `Android/aiwa_app/lib/core/push/push_service.dart:92` logs push-disable errors with `debugPrint`.
- Backend tests contain some direct diagnostic output.

Impact: Low. Release builds are unlikely to expose this materially, but redacted structured logging is cleaner.

Recommended fix:
- Route logs through project logging helpers with redaction rules.

## Positive Security Findings

- No real hardcoded production secret was found by targeted secret regexes. Hits were placeholders, CI-only examples, or test PEM material.
- Swagger/OpenAPI is disabled under the prod profile.
- Dev TOTP reset controller is gated by `@Profile("local")`.
- Caddy blocks external actuator access except health routes.
- Prometheus scraping uses bearer-token configuration inside the compose network.
- JWT default secret is refused outside local/test profiles.
- Admin 2FA is enforced server-side for SUPER_ADMIN and FINANCE under prod defaults.
- OTP has per-destination limits, global SMS budget, allowed-country filtering, single-use receipts, and Redis-down 503 behavior.
- Token revocation has database fallback when Redis is down.
- SQL query review found parameterized repository queries rather than obvious string-concatenated SQL injection paths.
- Private file resolution normalizes paths and checks the private storage root before serving private documents.
- Public uploads have file-size, decoder-size, and decode-concurrency controls; public images are re-encoded/metadata-stripped where possible.
- Admin React scan found no `dangerouslySetInnerHTML`, `innerHTML`, `eval`, `new Function`, or obvious DOM injection sink in `src`.
- Mobile auth token storage uses `flutter_secure_storage`; Android release manifest has `android:allowBackup="false"`.

## Commands / Tool Results

Backend tests:

```text
mvn test
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
Result: BUILD SUCCESS
Tests run: 384, Failures: 0, Errors: 0, Skipped: 0
```

Admin dependency audit:

```text
npm audit --audit-level=moderate --omit=dev
found 0 vulnerabilities

npm audit --audit-level=moderate
found 0 vulnerabilities
```

Backend dependency inventory:

```text
mvn -DskipTests dependency:tree
Result: BUILD SUCCESS
```

Backend CVE scan:

```text
mvn -DskipTests org.owasp:dependency-check-maven:12.1.8:check -Dformat=JSON -DfailBuildOnCVSS=11
Stopped manually after slow NVD feed progress: 20,000/401,169 records (5%) without an NVD API key.
No complete CVE result was produced.
```

Admin tests:

```text
npm test
Not run successfully: local node_modules are absent; command failed with 'vitest' is not recognized.
No npm install was performed during this audit.
```

Tool availability:

```text
Available locally: rg, git, mvn, npm, node, dart.
Not found locally in this pass: semgrep, gitleaks, trivy, snyk, flutter command through Get-Command.
```

## Recommended Security Backlog Order

1. Make production profile/provider hardening fail closed outside local/test.
2. Require TOTP, document, and backup encryption keys in production.
3. Prove off-server backup and restore from the off-server copy.
4. Move admin tokens out of localStorage.
5. Split broad `hasRole('ADMIN')` read/export endpoints into explicit least-privilege permissions.
6. Remove tracked JVM crash log and ignore future crash/log artifacts.
7. Add backend CVE scanning to CI with an NVD API key or managed scanner.
8. Add mobile release-build guard for HTTPS `API_BASE_URL`.
9. Add Redis fail-open alerts/fallbacks for high-risk throttles.
