# AIWA Production Audit, Round 2 - 2026-10-05

Repository: `D:\AIWA PROJECT\AIWA`, branch `main`, HEAD `7f59f37` (code identical to `30f0a66`; later commits are docs only).
Mode: audit and reporting only. **No application code was changed.** Only this file and `HANDOFF.md` were written.
Method: every claim from `HANDOFF.md`, `docs/audit/production-audit-2026-10-05/audit.md` and `docs/audit/security-audit-2026-10-05/security-audit.md` was re-checked against the current source, then the backend, Flutter app, admin dashboard, deployment, backups and CI were reviewed fresh. Where a claim could be reproduced it was (see section 5).

All line numbers are for HEAD. Paths are relative to the repo root.

---

## 1. Executive summary

The earlier audit fixes (S-01, S-02, S-05, S-06, S-07, S-10, S-11) are **present and effective in code**. The backend test suite passes (399/399) and the admin suite passes (115/115, `npm audit` clean, build OK). I found no critical vulnerability: no auth bypass, SQL injection, path traversal or route-level IDOR in the paths I traced.

Three things change the launch picture compared with the previous reports:

1. **The S-01 fix broke the CI gate that validates migrations (F-01, High, new).** The "Migrations + schema validation" step boots the jar with only `JWT_SECRET` set; the new fail-closed guard now refuses to start it. I reproduced this locally against a real PostgreSQL 16 container: 8 guard problems, process exits. CI on `main` should be red from `30f0a66` onward, and `deploy-staging` depends on that job. I could not read the GitHub run history (no `gh` CLI, no network credentials), so confirm in the Actions tab.
2. **A SUPPORT-role insider or a compromised SUPPORT account can take over any customer/provider account (F-03, Medium, new).** SUPPORT can edit a user's phone/email and then trigger a "temporary password" that is sent to the contact they just changed. SUPPORT does not require 2FA. The existing control ("password goes to the user, never the admin") is bypassable by chaining the two calls.
3. **Disaster recovery is still the real launch blocker (F-02, High, open).** Nothing in the repo copies backups off the server, and the documented `rclone sync` mirrors deletions and has no immutability.

Neither mobile nor the admin build has been exercised end to end on this machine: Flutter is not installed (the PATH entry `C:\flutter\src\flutter\bin` does not exist), so Flutter analyze/test/build, Android/iOS smoke, k6, the restore drill and provider sandbox checks remain **not run**.

**Recommendation: staging yes; production no** until F-01 is fixed and F-02 is closed with evidence (section 7).

## Remediation status (updated 2026-10-05, after the fix pass)

Sections 1 to 8 below are the findings as originally reported. This table is the current state. Backend `mvn test`: **404 run, 0 failures** (also 404/0 with `open-in-view` off). Admin: 115 tests pass, build OK. `backup_test.sh`: 31 passed. `docker compose config` and `caddy validate` accept the new deployment files. The F-01 CI environment was re-run against PostgreSQL 16 and Redis: guard passed, 32 migrations applied, `/actuator/health` returned 200.

| ID | Status | What changed |
| --- | --- | --- |
| F-01 CI gate | **Fixed, verified locally** | `.github/workflows/ci.yml` boots the jar with the prod profile and well-formed dummy providers/keys. Confirm green in GitHub Actions. |
| F-02 off-server backup | **Implemented, needs your bucket and a drill** | New `offsite` service (`deploy/backup/offsite.sh`, `rclone copy --immutable`, `rclone check`, `*.enc` only), compose requires `OFFSITE_REMOTE`; alerts `OffsiteBackupStale` / `OffsiteBackupMetricsMissing`; backup image now has openssl baked in (`deploy/backup/Dockerfile`); runbook rewritten with bucket versioning, write-only key, key escrow and a restore drill. **Still open:** creating the bucket, `deploy/secrets/rclone.conf`, escrowing the keys, and running and recording the drill. Backup encryption stays AES-256-CBC (changing it would break restores of existing backups). |
| F-03 SUPPORT takeover chain | **Fixed** | 2FA required for every admin (`AdminTwoFactorInterceptor`); changing a user's email/phone is SUPER_ADMIN only (`AdminUsersController.editUser`). Tests added/updated. |
| F-04 permissionless-admin PII reads | **Fixed** | User list/detail/activity need SUPPORT or FINANCE; complaints, verification queues and moderation list need SUPPORT. Counts and inbox stay any-admin. Test added. |
| F-05 admin tokens in localStorage | **Fixed, verified in a browser** | Access token in memory only, refresh token an HttpOnly SameSite=Strict cookie (admin accounts), CSRF header required on cookie refresh, tabs serialise refreshes with Web Locks. Details and deployment requirements: `docs/admin-session-hardening.md`. Admins sign in again once after the upgrade. |
| F-06 settlement controls | **Fixed** | `/admin/settlements/{id}/settle` requires `expectedAmount` and a payment `reference`, both audited; a settled-then-voided commission notifies every admin ("Refund due"); new counter `aiwa_booking_completed_total{cash}` and alert `CashNotCollectedRateHigh` (more than 20% of at least 10 completions in 6 h closed as cash not collected). |
| F-07 monitoring | **Implemented, untested on a host** | Log rotation, healthchecks, node-exporter (`HostDiskLow`, `HostMemoryLow`, `HostMetricsMissing`), DB pool alerts, `Watchdog` dead-man switch, and now redis-exporter with `RedisDown` / `RedisMetricsMissing`. Certificate expiry is covered by the outside uptime monitor (runbook updated), not by Prometheus. |
| F-08 `open-in-view` | **Fixed in prod and test profiles; verify on staging** | `application-prod.yml` and `application-test.yml` set it to false. Five lazy-loading failures found by running the suite that way were fixed (chat endpoints made transactional, review tags copied in the service). Local/dev keep `true`. |
| F-09 governance | **Template added, decisions still yours** | `docs/launch-signoff.md` (23 gates with owner/decision/date/evidence); SUPPORT 2FA decision recorded in `docs/security-review.md`. |
| F-10 local profile | **Fixed** | `DevTotpResetController` refuses to start unless the datasource is in-memory H2. |
| F-11 access-token cookie | **Fixed** | No longer issued (logout still clears a legacy one). |
| F-12 shadowed rule | **Fixed** | Dead `/providers/*/manage/**` rule removed. |
| F-13 `PageImpl` | **Fixed** | `StablePageJson` writes one fixed field set (same names the apps read); test added. |
| F-14 JWT secret | **Fixed** | Guard requires >= 32 bytes; UTF-8 explicit. |
| F-15 email OTP budget | **Fixed** | Email codes count against the global hourly/daily budget and its alert. |
| F-16 lockout reveals account | **Accepted** | Known trade-off of per-account lockout; mitigated by per-IP limits. |
| F-17 temporary password | **Fixed** | Temporary passwords issued by support expire after 24 h (`aiwa.auth.temp-password-hours`, migration `V33__temp_password_expiry.sql`, `User.tempPasswordExpiresAt`); sign-in with an expired one fails like a wrong password; the user sets their own via Forgot password (which clears the expiry); the SMS/email says so. There is no in-app change-password screen, so expiry was chosen over a "must change" flag. Test added. |
| F-18 CI supply chain | **Fixed except the secret** | Every action is pinned to a commit SHA (with the tag in a comment; Dependabot keeps them current). This also fixed a wrong Trivy tag (`v0.28.0`) in the new scan workflow. **Still yours:** set the `NVD_API_KEY` repository secret. |
| F-19 edge/env | **Fixed** | Backend gets an explicit variable list instead of the whole `.env`; `ADMIN_ALLOWED_IPS` restricts the admin site in Caddy (default still allows everyone: set it). |
| F-20 iOS/Android links | **Fixed in code, verify on macOS** | `PrivacyInfo.xcprivacy` added; Release and Profile builds now use `RunnerRelease.entitlements` with `aps-environment` = production (Debug keeps sandbox). The `aiwa://` scheme is kept for share links without a domain (accepted). Not built here: archive on macOS and check. |
| F-21 push token / admin mock | **Resolved** | `PushDeviceService.register` already reassigns a token to the newest account; mock code is now dropped from the production admin bundle (361 kB to 336 kB, marker string gone). |

Still needed from you before production: a bucket plus `rclone.conf` and a recorded restore drill (F-02), the signed `docs/launch-signoff.md` (F-09), `NVD_API_KEY`, `ADMIN_ALLOWED_IPS`, a staging run with `open-in-view` off (F-08), and the tests that cannot run on this machine (section 6).

## 2. Severity table

| Severity | Count | IDs |
| --- | ---: | --- |
| Critical | 0 | none confirmed |
| High | 2 | F-01 CI gate broken (new), F-02 no off-server backup (open) |
| Medium | 7 | F-03 SUPPORT takeover chain (new), F-04 permissionless-admin PII reads (new), F-05 admin tokens in localStorage (open, partly mitigated), F-06 settlement control gaps (new), F-07 monitoring blind spots (new), F-08 `open-in-view` (open), F-09 launch governance checklist (open) |
| Low | 12 | F-10 to F-21 |

## 3. Confirmed findings

### F-01 (High, NEW) - CI "Migrations + schema validation" step cannot pass since the S-01 guard

Evidence:
- `.github/workflows/ci.yml:58-77`: starts `java -jar target/*.jar` with only `SPRING_DATASOURCE_URL`, `DB_USERNAME`, `DB_PASSWORD`, `FLYWAY_ENABLED`, `JPA_DDL_AUTO`, `JWT_SECRET`. No `SPRING_PROFILES_ACTIVE`, no provider settings, no encryption keys.
- `aiwa-backend/src/main/java/com/aiwa/config/ProductionGuardConfig.java:32-33`: `@Profile("!local & !test")`, so it applies to the default profile.
- `ProductionGuardConfig.java:55-109`: requires prod profile, non-dev-log SMS/email/push, on-call phones, `TOTP_ENCRYPTION_KEY`, `DOCUMENT_ENCRYPTION_KEY`.
- `.github/workflows/ci.yml:190`: `deploy-staging` has `needs: [backend, admin]`.
- Reproduced locally (jar built from HEAD, PostgreSQL 16 container, exact CI env): `Refusing to start: this server is not production-safe (8 problems)` - profile, Swagger, SMS, push, email, on-call phones, TOTP key, document key.

Impact: the only check that runs the Flyway migrations and Hibernate `validate` against real PostgreSQL in CI cannot succeed, so schema drift is no longer caught. Staging auto-deploy is blocked. The temptation is to weaken the guard or skip the step; neither should happen.

Fix: give that CI step a valid hardened environment: `SPRING_PROFILES_ACTIVE=prod` plus dummy-but-well-formed values (`TOTP_ENCRYPTION_KEY`/`DOCUMENT_ENCRYPTION_KEY` as `openssl rand -base64 32`, `SMS_PROVIDER=external` with a dummy URL/key, `EMAIL_PROVIDER=http`, `PUSH_PROVIDER=fcm` plus a readable dummy credentials file, `SAFETY_ONCALL_PHONES=+2010...`) or `AIWA_ALLOW_NON_PROD_SERVER=true` together with the other values. Using the same values to also hit `/api/actuator/health` keeps the prod guard under test.

Acceptance: CI run on `main` is green including that step; removing any one required env var from the step turns it red.

### F-02 (High, OPEN; was H-01 / S-03) - No enforced off-server backup, and the documented method is weak

Evidence:
- `deploy/docker-compose.prod.yml:86` (`pgdata` local volume), `:116` (`./backups` on the same host), `:117` (`uploads` local volume). No service ships backups elsewhere.
- `docs/runbooks.md:119-123`: manual cron `rclone sync /srv/aiwa/deploy/backups remote:aiwa-backups --max-age 15d`. `sync` propagates deletions, so a wiped or ransomware-encrypted `backups/` directory replaces the remote copy on the next run; nothing requires bucket versioning or object lock.
- Key escrow is advice only: `deploy/.env.example:23-24` says to keep keys "in the backup of secrets". Losing `DOCUMENT_ENCRYPTION_KEY` makes every ID document and selfie unrecoverable; losing `BACKUP_KEY_FILE` makes every backup unrecoverable. Neither is checked anywhere.
- `deploy/backup/backup.sh:42`: installs `openssl` at run time with `apk add` (needs the Alpine mirror each time the container is recreated); on failure the backup fails, which is safe, but backup availability now depends on an external mirror.
- `deploy/backup/backup.sh:43-44`, `deploy/restore.sh:34`: AES-256-CBC with a passphrase, no authentication tag. Corruption is caught by the restore check, deliberate tampering is not.
- The heartbeat (`BACKUP_HEARTBEAT_URL`) is optional and only proves the local backup ran, not that anything left the server.

Impact: loss of the host, disk or provider account loses the database, all uploads and (possibly) the only copy of the keys. Identity documents cannot be re-collected.

Fix: either managed PostgreSQL with PITR plus object storage for uploads, or a compose service that pushes encrypted backups to a private bucket with versioning/object lock using `rclone copy` (not `sync`), with its own success metric and alert. Store both encryption keys in a password manager/secret store that is not on the server. Bake `openssl` into a small backup image instead of `apk add` at run time. Consider `age` or AES-GCM for authenticated backup encryption.

Acceptance: (a) a restore on a clean host from the off-server copy plus escrowed keys succeeds and is recorded with date and operator; (b) an alert fires when the off-server push is older than 26 h; (c) deleting local `backups/` does not remove the remote copy.

### F-03 (Medium, NEW) - SUPPORT can chain "edit contact" and "reset password" to take over an account; SUPPORT 2FA is optional

Evidence:
- `AdminUsersController.java:334-338` (`PATCH /admin/users/{id}`, `Perms.SUPPORT`): changes a non-admin user's email and phone with no confirmation by the owner (`:355-371`).
- `AdminUsersController.java:430-455` (`POST /admin/users/{id}/reset-password`, `Perms.SUPPORT`): generates a temporary password and sends it to the user's **current** phone/email (`deliverTemporaryPassword`, `:462-484`). After the contact edit above, that is the attacker's contact. The comment at `:441` ("never to the admin, who could otherwise sign in as them") is not enforced across the two calls.
- The user is only told afterwards, via a notification and a message to the **old** contacts (`notifyContactChanged`, `:383,393-420`), and only if those channels work (all wrapped in best-effort try/catch).
- `AdminTwoFactorInterceptor.java:291-292`: 2FA is required only for SUPER_ADMIN and FINANCE; SUPPORT passes without it.
- `AuthServiceImpl.java:277-302`: the public OTP password reset has no 2FA step either, so a SUPPORT admin account is also exposed to SIM-swap or email takeover.
- SUPPORT can also read ID documents and selfies (`VerificationController.java:182-199`).
- `docs/security-review.md:44` still lists "Confirm SUPPORT stays optional" as an open decision.

Impact: one compromised or malicious SUPPORT account (or a stolen SUPPORT browser profile, see F-05) can take over any customer or provider account, including a provider with an unsettled balance. Every step is audit-logged, but detection depends on someone reading the log (F-09).

Fix: require 2FA for every admin role. Require SUPER_ADMIN, or a second admin's approval, to change a user's phone/email; or block `reset-password` for N hours after a contact change; or send the temporary password only to the contact that existed before the change. Alert on "contact changed then password reset within 24 h".

Acceptance: a SUPPORT admin without 2FA gets 403 `auth.error.admin_2fa_required` on every non-`/auth` route; an API test shows `edit contact` followed by `reset-password` delivers to the old contact or is refused.

### F-04 (Medium, NEW) - Admin accounts with no permissions can still read user PII

Evidence:
- `security/Perms.java:226` (`ANY_ADMIN = hasRole('ADMIN')`) and the javadoc at `:210`: "Every admin (even one with no permissions) may call read-only endpoints".
- `AdminUsersController.java:30` (class-level `hasRole('ADMIN')`) with `:46` (list users, searchable by phone/email), `:120` (user detail), `:129` (activity); `VerificationController.java:44,94,104`; `ComplaintController.java:63`; `ModerationController.java:24`; `AdminInboxController.java:39`; `SupportController.java:58`; `AdminController.java:33`.
- S-05 narrowed only audit, settlements, booking and analytics reads.

Impact: an admin created for a narrow job, or a leftover account with its permissions removed, still enumerates every customer's and provider's contact data. Least privilege is not enforced for the largest PII surface.

Fix: gate user list/detail/activity, complaint, moderation and verification queues with `SUPPORT` (or a new read permission); keep only aggregate counts on `ANY_ADMIN`. Add the same kind of regression tests as `AdminReadExportRbacApiTest`.

Acceptance: an admin with an empty permission set gets 403 on those routes.

### F-05 (Medium, OPEN, partly mitigated; was M-01 / S-04) - Admin access and refresh tokens are in `localStorage`

Evidence: `aiwa-admin-dashboard-updated/src/api.js:6-20` (read/write), `:103,135,142` (refresh handling). Mitigations present: strong CSP without `unsafe-inline` for scripts (`aiwa-admin-dashboard-updated/deploy/nginx.conf.template:18`), no HTML-injection sinks in `src` (grep for `dangerouslySetInnerHTML`, `innerHTML`, `eval`, `new Function`, `document.write` found none), 30-minute idle sign-out (`api.js:59-80`), 15-minute access token and 8-hour admin refresh token (`application.yml:81,84`). The migration plan exists in `docs/admin-session-hardening.md`.

Impact: any future XSS, malicious extension or compromised profile can read a refresh token that is valid for up to 8 hours.

Fix: execute the plan in `docs/admin-session-hardening.md` (HttpOnly refresh cookie, in-memory access token). Until then keep the CSP and `npm audit` gate and make 2FA mandatory for all admins (F-03).

Acceptance: no `aiwa_admin_*` keys in `localStorage` after sign-in.

### F-06 (Medium, NEW) - Settlement and cash-flow control gaps

Evidence:
- `SettlementController.java:288-310` (`PATCH /admin/settlements/{id}/settle`, `Perms.FINANCE`): settles one ledger entry with no `expectedAmount`, no payment reference and no second approver. The batch path (`confirm-payout`, `:201-240`) does require the amount, so the single-entry route is the weaker side door.
- `BookingServiceImpl.java:1641-1652` (`voidCommission`): when a payment is lost after its commission was already `SETTLED`, the only action is `log.warn("... refund it to the provider")`. No ledger entry, notification, metric or alert records the money owed back.
- `BookingServiceImpl.java:755-780` (`complete`): commission is created only when the provider declares `cashCollected=true`; `false` goes to DISPUTED with no commission. This is an intentional design with an admin dispute review, but it gives the provider a way to avoid commission, and detection relies on disputes being worked. There is no metric on per-provider dispute rate.

Impact: a single FINANCE account can forgive commission silently (audit-logged only); refunds owed to providers can be missed; commission avoidance is not measured.

Fix: require `expectedAmount` and a free-text payment reference on `/settle` (or remove it in favour of `confirm-payout`); on settled-then-voided, write a `REFUND_DUE` ledger entry or admin notification plus a counter metric; add a per-provider "cash not collected" rate to the finance view and an alert threshold.

Acceptance: `/settle` without amount/reference returns 400; a voided settled entry produces an admin-visible record.

### F-07 (Medium, NEW) - Monitoring and runtime blind spots

Evidence:
- `deploy/monitoring/alerts.yml:7-127` covers backend up, SOS, SMS/push, sign-in, OTP budget, rate-limit Redis, backups, 5xx, latency, heap. It has **no** rule for: host disk or inode usage (PostgreSQL `pgdata`, `uploads`, `backups` all share the host), PostgreSQL down or connection-pool saturation (`hikaricp_connections_pending`), Redis down (only the rate-limit fallback counter exists), TLS certificate expiry, container restarts, or a dead-man's-switch for Prometheus/Alertmanager themselves (`AlertingPipelineDown` is evaluated by the same Prometheus).
- `deploy/docker-compose.prod.yml`: no `logging:` options on any service, so Docker's default `json-file` driver grows without limit; `caddy` and `admin` have no healthcheck and `depends_on` only waits for container start (`:33`).
- Hikari pool is 20 (`application.yml:33`) while `open-in-view` is on (F-08).

Impact: disk-full on a single-host stack (database, uploads, backups and logs together) is the most likely production outage and nothing would warn first.

Fix: add node-exporter (or cAdvisor) with disk/inode/memory alerts, a `DbPoolSaturated` alert on Hikari metrics, `max-size`/`max-file` log options, healthchecks for caddy/admin, an external dead-man's-switch ping, and a certificate-expiry probe.

Acceptance: filling a test volume above 85 % triggers an alert in staging.

### F-08 (Medium, OPEN; was M-02) - `spring.jpa.open-in-view: true`

Evidence: `aiwa-backend/src/main/resources/application.yml:57-62` (kept deliberately), `:30-33` (pool sized around it). Unchanged since the last audit.

Impact: a database connection is held for the full request including JSON serialisation and slow clients; combined with a pool of 20, a slow-client burst can exhaust the pool.

Fix: map lazy relations inside `@Transactional` service methods or with entity graphs, then set `open-in-view: false` and run the API smoke and k6 tests (`deploy/loadtest/smoke.js`) on staging.

Acceptance: staging runs with `false` and the 399-test suite plus k6 smoke pass.

### F-09 (Medium, OPEN; was M-04) - Launch governance decisions are not recorded

Evidence: `docs/security-review.md:16,33,44,45,59,60,70,74,75,76` are still unchecked: lookup paths, token lifetimes, SUPPORT 2FA, key setup, SUPER_ADMIN holders (at least two), mandatory removal of `ADMIN_PASSWORD`, rate limits, audit-log review cadence, admin offboarding, incident contact.

Impact: F-03, F-06 and F-02 are all "someone must notice" controls; nobody is assigned.

Fix: turn the checklist into a signed launch record (owner, decision, date, evidence link). Note `AdminBootstrapConfig.java:44-66` and `deploy/.env.example:84-86` mean `ADMIN_PASSWORD` stays in `.env` and in the backend's environment until an operator removes it.

### Low findings

| ID | Finding | Evidence | Fix |
| --- | --- | --- | --- |
| F-10 | The `local` and `test` profiles bypass the whole guard, and `local` exposes an unauthenticated 2FA wipe plus H2 console and a hard-coded admin password. A server accidentally started with `SPRING_PROFILES_ACTIVE=local` is fully open. | `ProductionGuardConfig.java:33`; `SecurityConfig.java:79` (`/dev/2fa/**` permitAll); `controller/DevTotpResetController.java:27-52`; `application-local.yml:12-15,29-32` | Make the guard refuse `local`/`test` unless the datasource URL is in-memory H2 or the bind address is loopback; or remove `/dev/2fa/**` from `PUBLIC_URLS` and require an admin. |
| F-11 | The access-token cookie is still issued on every login/refresh/2FA even though the filter no longer accepts it; `logout` still reads it. Dead surface, `Secure` only if `AUTH_COOKIE_SECURE`. | `AuthController.java:69,93,104,214,226,390,394-403`; `JwtAuthFilter.java:80-83` | Stop issuing the cookie; drop the `@CookieValue` in logout. |
| F-12 | Dead and shadowed rule: `GET /providers/**` is `permitAll` and appears before `/providers/*/manage/**` (`hasRole PROVIDER`), so any future `GET .../manage/...` endpoint would be public. No controller maps `manage` today. | `SecurityConfig.java:99` vs `:110`; `grep manage controller` finds none | Delete the rule or move it above the permitAll. |
| F-13 | API returns raw Spring `PageImpl` JSON (10 `PageImpl` uses, 22 paged responses). Unchanged. | `grep PageImpl aiwa-backend/src/main` | Stable page DTO. |
| F-14 | JWT secret strength is never validated; the guard only rejects the checked-in default. A short secret fails at first token use, not at startup. `getBytes()` uses the platform charset. | `JwtSecretGuardConfig.java:170-181`; `JwtUtils.java:29-31` | Add a length >= 32 bytes check to the guard; use UTF-8 explicitly. |
| F-15 | Email OTP has no global budget or recipient throttle beyond 3/10 min per address and 5/min per IP, so the endpoint can be used to mail many different victims. SMS has country, per-number and global budgets. | `OtpServiceImpl.java:73-83` (SMS) vs `:130-136` (email); `RedisRateLimitFilter.java:116-127` | Add a global hourly/daily email budget and the same alert as SMS. |
| F-16 | Account lock after 5 failures reveals that an account exists (429 vs 401 only for real accounts) and allows deliberate 15-minute lock-out of a victim. Known trade-off. | `AuthServiceImpl.java:118-119,429-435`; `application.yml:160-161` | Consider per-IP plus per-account throttling and a uniform response. |
| F-17 | Admin-issued temporary passwords are not marked "must change" and stay valid until used. | `AdminUsersController.java:486-492`; no `mustChangePassword` field in use | Force a change at next login. |
| F-18 | CI supply chain: actions pinned by tag (`@v4`), not commit SHA; no CodeQL/secret scanning/container image scan; the OWASP job skips silently without `NVD_API_KEY` (still not run); Dockerfiles do not use `npm ci --ignore-scripts`. | `.github/workflows/ci.yml:37,38,83,84,106,124,162,168,179`; `:150-160`; `aiwa-admin-dashboard-updated/Dockerfile:8` | Pin SHAs, enable CodeQL and Trivy, set `NVD_API_KEY`, make the missing key a failure on `main`. |
| F-19 | Edge hardening: the admin site is reachable from the whole internet with no IP allow-list, VPN or edge rate limit (only app-level limits). The backend container receives the entire `.env` (DB password, alert SMTP/Telegram secrets, `ADMIN_PASSWORD`). | `deploy/Caddyfile:29-32`; `deploy/docker-compose.prod.yml:41` (`env_file: .env`) | Restrict `ADMIN_DOMAIN` by IP/VPN; pass only the variables the backend needs. |
| F-20 | iOS: no `PrivacyInfo.xcprivacy` in the app target (the app uses `shared_preferences`/UserDefaults and location); `aps-environment` is `development` in the checked-in entitlements (Xcode rewrites it on export, verify on the archive). Android: custom scheme `aiwa://app` is unverified and hijackable by another app (low impact, it only routes to provider pages). | `find ios -iname PrivacyInfo*` returns nothing; `ios/Runner/Runner.entitlements:104-105`; `AndroidManifest.xml:34-40` | Add the privacy manifest; check the archive entitlement; prefer the verified `https` App Link for sharing. |
| F-21 | Push token removal on sign-out is best-effort; if the phone is offline at sign-out the previous user's token stays registered until another account registers that token. Mock-mode data (`mock-admin-access-token`) ships in the admin bundle but is off unless `VITE_USE_MOCKS=true`, which the Dockerfile never sets. | `Android/aiwa_app/lib/core/push/push_registrar.dart:48-69`; `aiwa-admin-dashboard-updated/src/api.js:977-985` | Backend: reassign a token to the newest registering user (verify `pushDevices.register` does this); build the admin without mock code via a Vite define. |

## 4. False positives, old findings now fixed, and verified controls

Verified fixed in current code (evidence checked this round):

| Old ID | Verdict | Evidence |
| --- | --- | --- |
| S-01 fail-closed prod guard | Fixed (but see F-01 for the CI side effect) | `ProductionGuardConfig.java:32-33,55-109`; reproduced refusal at runtime |
| S-02 / H-02 encryption keys required | Fixed | `ProductionGuardConfig.java:107-108,130-144`; `deploy/docker-compose.prod.yml:51-52,115`; `deploy/backup/backup.sh:65-74` refuses unencrypted backups |
| S-05 admin read/export RBAC | Fixed for audit/finance/bookings/analytics | `Perms.java:237-239`; `AuditController.java:16`; `SettlementController.java:101,115,129,138,241`; `AdminController.java:102,119`; `AnalyticsController.java:33`. (Wider PII reads: F-04) |
| S-06 tracked crash log | Fixed | `git ls-files` has no `hs_err*`; `.gitignore:21-24`, `aiwa-backend/.gitignore` |
| S-07 / M-03 Redis fail-open throttles | Fixed with in-process fallback, metric and alert; one `catch` still allows through on an unexpected exception | `RedisRateLimitFilter.java:153-174`; `alerts.yml:65-72` |
| S-08 mobile release API base | Fixed in code; **not verified by a run** | `android/app/build.gradle.kts:76-89`; `lib/main.dart:16-21`; `lib/core/constants/api_constants.dart:13-16`; CI step `ci.yml:136-148` |
| S-10 / L-01 stale env docs | Fixed | `aiwa-backend/.env.example:20` uses `GOOGLE_APPLICATION_CREDENTIALS` |
| S-11 / L-03 debug output | Fixed | no `debugPrint` or `System.out` left in `lib/` or `src/` |
| S-09 CVE scan | Wired, **never run** | `ci.yml:150-185`, skips without `NVD_API_KEY` |

Re-checked and found sound (no finding):
- JWT: separate `typ` for access/refresh/MFA, MFA challenge single-use, refresh rotation with DB-backed revocation, per-user session cut-off, user reloaded on every request (`JwtAuthFilter.java:36-67`, `JwtUtils.java:40-107`, `AuthServiceImpl.java:146-261`).
- TOTP: step replay guard (`claimTotpStep`), re-auth to change 2FA, secret AES-GCM at rest (`AuthServiceImpl.java:175-224,394-446`, `util/TotpSecretConverter.java`).
- OTP: 6 digits from `SecureRandom`, constant-time compare, atomic single use, attempt cap, receipt-bound registration, country and global budget (`OtpServiceImpl.java:104-217`).
- Object ownership: bookings, chat, staff, availability, notifications, safety all check the caller (`BookingServiceImpl.java:458-465,522-527,569-571,744-750`; `ChatController.java:226-231`; `StaffController.java:72-86`).
- Private documents: path normalised and confined to the private root, document must be one a provider submitted, SUPPORT-only and audit-logged (`FileStorageServiceImpl.java:145-155`, `VerificationController.java:176-199`); uploads validated by magic bytes, random file names, public images re-encoded (`FileStorageServiceImpl.java:162-227,499`); AES-256-GCM with random IV for private files (`util/PrivateFileCipher.java`).
- SQL: all repository `@Query` use bind parameters; the only string-built SQL is the V19 migration using internal column names (`config/V19__Normalise_identifiers.java:74-85`). Only wildcard (`%`/`_`) characters in a name search are unescaped (`ProviderProfileRepository.java:94`): not injection, minor performance abuse.
- Admin front end: no DOM injection sinks; external links use `rel="noreferrer"`; the only user-controlled `href` (`App.jsx:3794`) is a server-stored upload path and CSP blocks `javascript:`.
- Deployment: only Caddy publishes ports; Postgres/Redis/Prometheus are internal; actuator blocked except health at the edge and token-guarded in app (`deploy/Caddyfile:20-26`, `security/MetricsTokenFilter.java:216-235`); backend container is read-only, non-root, `cap_drop: ALL`, `no-new-privileges` (`deploy/docker-compose.prod.yml:56-59`); images pinned to exact versions.
- Secrets: regexes for cloud keys, private keys, tokens and quoted credentials found only placeholders, CI-only values and test PEM. `android/key.properties` is git-ignored (`android/.gitignore:12`) and references a keystore outside the repo.
- Dependencies: `npm audit` 0 vulnerabilities (full and `--omit=dev`); Spring Boot 3.5.16 parent. Backend CVE matching is **not** proven (S-09).
- The `/admin` endpoints I sampled enforce mutation permissions (SUPPORT/FINANCE/SUPER_ADMIN) and protect the last super admin with a lock (`AdminUsersController.java:193-243,311-335`).

## 5. Tests and commands run

| Check | Command / method | Result |
| --- | --- | --- |
| Git state | `git status`, `git log` | clean tree at start; HEAD `7f59f37` |
| Backend tests | `mvn -B test` with JDK 17 (`C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`) | **BUILD SUCCESS, 399 run, 0 failures, 0 errors, 0 skipped** |
| Admin tests | `npm test` (Node 20.20.2 from nvm) | 20 files, **115 passed** |
| Admin build | `npm run build` with `VITE_API_BASE_URL=https://api.example.invalid/api` | OK (`dist/assets/index-*.js` 361 kB) |
| Admin dependency audit | `npm audit --audit-level=moderate`; `npm audit --omit=dev --audit-level=high` | 0 vulnerabilities |
| Backend package | `mvn -B -q package -DskipTests` | OK |
| CI-step reproduction (F-01) | built jar run with the exact env of `ci.yml:58-70` against a throwaway `postgres:16-alpine` container (removed afterwards) | refused to start, 8 problems listed |
| Static sweeps | `git grep` for key/secret patterns, TODO/FIXME, non-local `http://`, `System.out`, `debugPrint`, string-built SQL, `PreAuthorize` coverage, broad `hasRole('ADMIN')`, DOM sinks, `localStorage` | results folded into sections 3 and 4 |

Local environment notes: the default `java` is 1.8 and the default `node` is 12, so JDK 17 and Node 20 were selected explicitly. A first attempt to run Maven and Vitest at the same time exhausted the Windows paging file and killed both; they were re-run one at a time and passed.

## 6. Tests not run, and why

| Not run | Why | How to verify |
| --- | --- | --- |
| `flutter analyze`, `flutter test`, goldens | Flutter SDK is not installed here (`C:\flutter\src\flutter\bin` in PATH does not exist; only `dart` is present) | CI `flutter` job (Windows, pinned 3.47.5) or install Flutter and run in `Android/aiwa_app` |
| Android release build guard, signed AAB, Android/iOS device smoke, push delivery, deep links | no SDK/device here | `tool/build_release.sh appbundle`, then smoke on a real device; confirm the CI step `ci.yml:136-148` passes |
| iOS build, privacy manifest, archive entitlements | needs macOS and Xcode | archive on macOS, inspect entitlements and privacy report |
| OWASP Dependency-Check / backend CVE scan | needs `NVD_API_KEY`; NVD feed without a key takes hours | set the repo secret and run the `dependency-scan` job |
| GitHub Actions run history (confirming F-01 on the server) | no `gh` CLI or credentials here | open the Actions tab for `main` after `30f0a66` |
| k6 smoke (`deploy/loadtest/smoke.js`), production compose smoke, TLS/Caddy behaviour | no staging stack or domain here; compose stack not started | `docker compose -f deploy/docker-compose.prod.yml up` on staging, then `k6 run` |
| Restore drill from backup and from an off-server copy | no backups or staging host | `deploy/restore_test.sh` plus the drill in F-02 acceptance |
| SMS/email/FCM sandbox sends | needs provider credentials | staging with real providers: sign-up OTP, password reset, SOS text, push |
| Secret scanners (gitleaks, trivy, semgrep, snyk) | not installed | run in CI (F-18) |
| Manual penetration tests (rate limits behind Caddy, XFF spoofing, CORS) | no deployed stack | verify `X-Forwarded-For` cannot be spoofed through Caddy and that only the admin origin is in `CORS_ALLOWED_ORIGINS` |

## 7. Production launch recommendation

- **Staging: yes**, after F-01 is fixed so the pipeline is trustworthy, and with real provider secrets.
- **Production: not yet.** Required before launch:
  1. F-01 fixed and CI green on `main`.
  2. F-02 closed with evidence: off-server encrypted copy, versioned/immutable bucket, key escrow, a restore drill from that copy, stale-copy alert.
  3. F-03 decided and implemented: 2FA for every admin and a guard on the contact-change then reset chain.
  4. F-07 minimum: disk, DB-pool and log-rotation controls.
  5. F-09 signed off (named owners, at least two SUPER_ADMIN holders, `ADMIN_PASSWORD` removed from `.env`).
  6. The "not run" items in section 6: at least Flutter analyze/test via CI, a signed release build, device smoke on both platforms, k6 smoke, and provider sandbox tests.
- Accepted-with-plan for launch if time is short: F-05 (admin token storage) with 2FA on all admins and the idle timeout, F-08 (`open-in-view`) with a documented traffic ceiling.

## 8. Prioritised fix list

1. **F-01** - give the CI migration step a valid hardened environment (small, unblocks everything).
2. **F-02** - off-server, versioned, encrypted backups; key escrow; restore drill; alert.
3. **F-03** - 2FA for all admins; protect contact-change then reset.
4. **F-07** - disk/DB/Redis/cert alerts, log rotation, healthchecks, dead-man's-switch.
5. **F-04** - SUPPORT-gate PII read endpoints; regression tests.
6. **F-06** - amount and reference on `/settle`; `REFUND_DUE` record; dispute-rate metric.
7. **F-09** - signed launch checklist.
8. **F-05** - cookie/BFF admin session (follow `docs/admin-session-hardening.md`).
9. **F-08** - disable `open-in-view` on staging, fix lazy mappings, k6.
10. **F-18, F-10, F-14, F-12, F-11** - CI scanning and SHA pinning, local-profile hardening, JWT secret length, dead rules and cookie.
11. **F-20, F-21, F-19, F-15, F-16, F-17, F-13** - iOS privacy manifest and entitlement check, push token reassignment, admin edge allow-list and scoped `env_file`, email OTP budget, lockout response, forced password change, page DTO.
