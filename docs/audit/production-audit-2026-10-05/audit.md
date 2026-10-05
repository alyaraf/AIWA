# AIWA Production Audit - 2026-10-05

Scope: backend, Flutter mobile app, admin dashboard, deployment, CI, and operations documentation in `D:\AIWA PROJECT\AIWA`.

Audited revision: `410495a` (`System audit fixes SA-01 to SA-15: MFA scope, OTP receipt, restore safety, and more`) on `main`, matching `origin/main` at audit time.

Audit mode: static source review plus backend test execution. I did not make application-code changes in this pass.

## Executive Summary

The current `main` is much stronger than the stale handoff suggested. The earlier critical items around route-level authorization, OTP pumping, external SMS failures, Swagger exposure in prod, provider suspension, support password reset delivery, token revocation during Redis outages, FCM production config, and private-file traversal appear addressed in the inspected code.

I did not confirm any new critical code defect during this pass. The project is close enough for a controlled staging release, but not for an unsupervised production launch until the remaining operational controls below are closed and verified in the real deployment environment.

## Severity Summary

| Severity | Count | Status |
| --- | ---: | --- |
| Critical | 0 | No confirmed critical code vulnerability found in this pass. |
| High | 2 | Disaster recovery and sensitive-at-rest controls need launch gating. |
| Medium | 4 | Admin token storage, open-in-view, Redis fail-open limits, launch governance. |
| Low | 3 | Stale env example, unstable Page JSON shape, minor debug/test hygiene. |

## Remediation status (commit `30f0a66`, 2026-10-05)

| ID | Status | Notes |
| --- | --- | --- |
| H-01 Off-server backups | **Open** | Operational: off-server sync and restore drill still needed. |
| H-02 Encryption optional | **Fixed** | TOTP and document keys required at startup; backup key required by compose and `backup.sh`. |
| M-01 Admin tokens in localStorage | **Partly fixed** | Idle sign-out; cookie migration plan in `docs/admin-session-hardening.md`. |
| M-02 `open-in-view` | **Open** | Not addressed. |
| M-03 Redis fail-open limits | **Fixed** | In-process fallback, metric and alert. |
| M-04 Launch governance checklist | **Open** | Decisions still need owners and dates; `ADMIN_PASSWORD` removal is now mandatory in the docs. |
| L-01 Stale `.env.example` | **Fixed** | Uses `GOOGLE_APPLICATION_CREDENTIALS`. |
| L-02 `PageImpl` JSON | **Open** | Not addressed. |
| L-03 Debug output | **Fixed** | Logging helper replaces `debugPrint`. |

Tests after the fixes: backend 399 run, 0 failures; admin 115 pass. Flutter, k6, restore drill and provider sandbox checks are still not run.

## High Priority Findings

### H-01: Off-server backups are documented but not enforced by deployment

Evidence:
- `deploy/docker-compose.prod.yml:82-83` stores PostgreSQL data in the local `pgdata` Docker volume.
- `deploy/docker-compose.prod.yml:90-113` writes nightly database and uploads backups to local `./backups` and local `uploads` volume.
- `docs/runbooks.md:113-123` correctly says a same-disk backup does not survive server loss and recommends nightly `rclone`, but this is an operator step, not a deployed service or CI-verified control.

Impact: Losing the server, disk, or provider account can lose both the primary database/uploads and the default local backup copy unless off-server sync or managed database PITR is configured outside the repo.

Recommended fix:
- Treat production as blocked until one of these is true and tested: managed PostgreSQL with PITR plus object storage for uploads, or an automated off-server backup sync with private bucket, encryption, heartbeat, and restore drill.
- Add a documented acceptance record: last successful off-server backup timestamp, last restore-test timestamp, and who receives stale-backup alerts.

Acceptance criteria:
- Restore drill from an off-server copy succeeds on a clean host.
- Alert fires when off-server sync or backup heartbeat fails.
- `BACKUP_KEY_FILE` is set and backup encryption metric is healthy.

### H-02: Sensitive-at-rest encryption is optional at launch

Evidence:
- `aiwa-backend/src/main/java/com/aiwa/config/ProductionGuardConfig.java:88-92` warns when `TOTP_ENCRYPTION_KEY` is missing, but production still starts.
- `aiwa-backend/src/main/java/com/aiwa/service/impl/FileStorageServiceImpl.java:102-103` initializes private-file encryption from `DOCUMENT_ENCRYPTION_KEY`; if absent, encryption is disabled.
- `aiwa-backend/src/main/java/com/aiwa/service/impl/FileStorageServiceImpl.java:504-508` encrypts private files only when `privateCipher.enabled()` is true.
- `docs/runbooks.md:81-97` makes backup encryption optional and alert-based.

Impact: Admin TOTP secrets, provider ID documents, selfies, and backup artifacts may be stored plaintext if deployment secrets are incomplete. This is especially sensitive because verification documents are regulated identity material.

Recommended fix:
- Make `TOTP_ENCRYPTION_KEY`, `DOCUMENT_ENCRYPTION_KEY`, and `BACKUP_KEY_FILE` hard production prerequisites or add an explicit documented launch waiver.
- Keep key rotation and loss procedures in the runbook.

Acceptance criteria:
- Production boot refuses missing TOTP and document encryption keys, or a signed waiver exists.
- Existing private documents written after deployment are encrypted and readable after restart.
- Restore from encrypted backup succeeds.

## Medium Priority Findings

### M-01: Admin refresh and access tokens live in localStorage

Evidence:
- `aiwa-admin-dashboard-updated/src/api.js:6-20` stores admin access and refresh tokens in `window.localStorage`.
- `aiwa-admin-dashboard-updated/deploy/nginx.conf.template` has a strong CSP, which helps, but does not protect against all future XSS, browser extension, or local-device compromise scenarios.

Impact: Any script execution in the admin origin can exfiltrate long-lived admin refresh tokens. The current admin refresh-token lifetime defaults to 8 hours in `application.yml`, reducing but not removing the risk.

Recommended fix:
- Move admin sessions to HttpOnly, Secure, SameSite cookies or a BFF session model.
- If localStorage remains temporarily, shorten admin refresh lifetime further and keep CSP, dependency scanning, and admin 2FA mandatory.

### M-02: `spring.jpa.open-in-view` is intentionally enabled

Evidence:
- `aiwa-backend/src/main/resources/application.yml:57-62` states entity lazy relations are mapped after repository calls and keeps `open-in-view: true`.
- `application.yml:30-34` increases Hikari pool size partly because open-in-view holds a DB connection through the whole request.

Impact: Slow clients, JSON serialization, or controller work can hold database connections longer than necessary. Under peak traffic, this can cause connection pressure and noisy latency. It is not an immediate security vulnerability, but it is a scalability and operability risk.

Recommended fix:
- Move response mapping for lazy relations into transactional service methods or explicit repository/entity-graph queries.
- Disable open-in-view in staging and run API smoke/load tests before production.

### M-03: Several rate-limit paths fail open when Redis is unavailable

Evidence:
- `aiwa-backend/src/main/java/com/aiwa/security/RedisRateLimitFilter.java:57-72` deliberately allows auth requests through when Redis rate-limit checks fail.
- `aiwa-backend/src/main/java/com/aiwa/service/impl/AccountRateLimiter.java` documents account-level action limits as Redis-backed and fail-open.
- OTP itself fails closed when Redis is down (`OtpServiceImpl` returns 503), and token revocation falls back to the database, so this is scoped to abuse throttling rather than the core auth boundary.

Impact: During a Redis outage, brute-force and abuse resistance is weaker, especially for login and account actions. Some controls remain safe, but the degradation should be visible to operations.

Recommended fix:
- Add alerting on Redis outage plus rate-limit fail-open log events.
- Consider DB-backed fallback counters for login/admin routes, or fail-closed for selected high-risk admin endpoints after UX review.

### M-04: Launch security/governance checklist still has undecided items

Evidence:
- `docs/security-review.md:16`, `33`, `44-46`, `59-60`, `70`, and `74-76` contain open launch decisions about lookup paths, token lifetimes, SUPPORT 2FA scope, encryption keys, super-admin holders, `ADMIN_PASSWORD` removal, rate-limit numbers, audit-log review, admin offboarding, and incident ownership.

Impact: The code may be ready for staging, but the operational ownership model is not fully closed. For a marketplace handling payments, identity documents, and safety/SOS flows, these decisions should be explicit before production.

Recommended fix:
- Convert the open checklist into a launch sign-off document with owner, decision, date, and evidence.

## Low Priority Findings

### L-01: Backend `.env.example` contains stale FCM variable naming

Evidence:
- `aiwa-backend/.env.example:20` refers to `FIREBASE_SERVICE_ACCOUNT_FILE`, while current production guard and compose use `GOOGLE_APPLICATION_CREDENTIALS`.

Impact: Backend-only or manual deploys can be misconfigured even though `deploy/docker-compose.prod.yml` is correct.

Recommended fix: Update the backend example to match current production variable names or clearly mark it as legacy/local-only.

### L-02: API exposes Spring `PageImpl` JSON shape

Evidence:
- Backend test logs warn that serializing `PageImpl` directly is not stable.
- Several controllers return paged responses consumed by mobile/admin clients.

Impact: A Spring upgrade can subtly change pagination JSON and break clients.

Recommended fix: Return a stable project-owned page DTO or Spring HATEOAS `PagedModel` from public/admin APIs.

### L-03: Minor debug/test-output hygiene remains

Evidence:
- `Android/aiwa_app/lib/core/push/push_service.dart:92` uses `debugPrint('Push disabled: $e')`.
- Backend tests contain a small number of `System.out.println` calls.

Impact: Low in release builds, but noisy logs can leak implementation detail during support/debug sessions.

Recommended fix: Route through the app logger with redaction and keep test output quiet unless diagnostics are needed.

## Confirmed Strengths

Backend/security:
- Prod Swagger/OpenAPI is disabled in `application-prod.yml`.
- `SecurityConfig` uses specific public paths and method security; public file access is scoped to `/files/public/**`.
- Admin 2FA is enforced server-side for SUPER_ADMIN and FINANCE by `AdminTwoFactorInterceptor`; SUPPORT is intentionally optional pending launch decision.
- External SMS/email services throw on transport and refusal responses instead of silently succeeding.
- OTP has per-destination limits, global SMS budget, allowed country codes, constant-time comparison, single-use receipts, and Redis-down 503 behavior.
- Token revocation and refresh-token reuse protection have database fallback when Redis is down.
- Provider suspension, booking lifecycle rules, commission snapshots, settlement pause logic, travel-fee caps, and idempotency records are materially improved over stale notes.
- Private-file path resolution prevents traversal and public image processing has decoder-size/concurrency guards.
- Account deletion blocks live bookings/commission debt and anonymizes rather than hard-deleting referenced users.

Mobile:
- Flutter uses secure storage for mobile auth tokens.
- API constants mostly align with backend routes and media URL handling.
- Registration OTP receipt handoff is implemented in the auth remote data source.
- Android package queries and iOS URL schemes are present for phone, maps, WhatsApp, and app-link/deep-link flows.

Admin/dashboard:
- Admin deployment config uses a strong CSP and frame protection.
- API client handles token refresh, 2FA challenge routing, cross-tab token clearing, and role-forbidden behavior.

Deployment/ops:
- Compose includes Caddy, backend, admin, PostgreSQL, Redis, backup, Prometheus, and Alertmanager.
- Caddy blocks actuator exposure except health routes.
- Backup script verifies dumps and upload tarballs before marking success.
- Runbooks cover restore, backup encryption, off-server backup guidance, SOS, verification, disputes, and alerts.

CI:
- GitHub Actions cover backend H2 and PostgreSQL tests, admin lint/test/build/audit, Flutter analyze/test, Android debug APK, and conditional staging deploy.

## Tests Run

Backend:

```text
Command: mvn test
Environment: JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
Result: BUILD SUCCESS
Tests: 384 run, 0 failures, 0 errors, 0 skipped
Finished: 2026-10-05T10:47:24+03:00
```

Notes:
- `mvn -o test` could not run because the Spring Boot 3.5.16 parent POM was not cached offline.
- `mvn test` under the default Java failed because the default runtime was Java 8. Re-running with JDK 17 succeeded.

Not run in this pass:
- Admin `npm test`, `npm run build`, `npm audit`.
- Flutter `flutter analyze`, `flutter test`, Android/iOS device smoke tests.
- k6 smoke, production compose smoke, restore drill, payment/notification provider sandbox tests.

## Release Recommendation

Staging: Yes, if the environment uses real SMS/email/push providers and real deployment secrets.

Production: Not yet. Require sign-off on:
1. Off-server backup and restore drill evidence.
2. Required encryption keys for TOTP secrets, private documents, and backups.
3. Admin token storage risk accepted or mitigated.
4. Security-review open decisions closed.
5. Admin, Flutter, Android/iOS, k6, restore, and provider integration tests completed.

## Suggested Next Engineering Queue

1. Add hard production guards for `DOCUMENT_ENCRYPTION_KEY` and, preferably, `TOTP_ENCRYPTION_KEY`.
2. Automate or codify off-server backup sync and restore-test evidence.
3. Move admin auth away from localStorage.
4. Remove `open-in-view` by moving response mapping into transactional service boundaries.
5. Add Redis fail-open alerting and decide which throttles should fail closed.
6. Replace raw `PageImpl` API JSON with a stable DTO.
7. Refresh stale env examples and close `docs/security-review.md` checkboxes with dated decisions.
