# AIWA Handoff

Last updated: 2026-10-05 (audit round 2, after the S-01..S-11 fixes)

Project path: `D:\AIWA PROJECT\AIWA`
Branch: `main`
Audited commit: `410495a` (`System audit fixes SA-01 to SA-15: MFA scope, OTP receipt, restore safety, and more`)
Git state at audit time: `main...origin/main`, with `HANDOFF.md` untracked locally before this refresh.

## Current State

A full production-readiness audit was performed against the current repository. The stale handoff content from the older `fix/qa-round` branch no longer matched the codebase: current `main` already contains many of the high-risk fixes it listed as open.

New audit artifact:

- `docs/audit/production-audit-2026-10-05/audit.md`

No application code was changed during this audit pass. Documentation was updated only.

## Audit round 2 (2026-10-05, HEAD `7f59f37`) - read this first

Report: `docs/audit/production-audit-2026-10-05-r2/audit.md` (audit only, no application code changed).

Verified against current code: S-01, S-02, S-05, S-06, S-07, S-10, S-11 are fixed. Backend `mvn test` (JDK 17): 399 run, 0 failures.
Admin: 115 tests pass, build OK, `npm audit` 0 vulnerabilities. No critical finding.

New or still-open items, in fix order:

1. **F-01 (High, new): CI is broken for the "Migrations + schema validation" step.** `ProductionGuardConfig` (S-01) now applies to the
   default profile, and `.github/workflows/ci.yml:58-77` starts the jar with only `JWT_SECRET`. Reproduced locally against PostgreSQL 16:
   8 guard problems, startup refused. `deploy-staging` needs that job. Fix the CI env; do not weaken the guard. Confirm in the Actions tab.
2. **F-02 (High, open): no enforced off-server backup.** The documented `rclone sync` mirrors deletions and has no versioning/object lock;
   key escrow for `DOCUMENT_ENCRYPTION_KEY` and `BACKUP_KEY_FILE` is advice only. Needs a restore drill from the off-server copy.
3. **F-03 (Medium, new): SUPPORT can edit a user's phone/email and then send a temporary password to that new contact** (account takeover
   chain); SUPPORT 2FA is optional. Require 2FA for every admin and guard the edit-then-reset chain.
4. F-07 monitoring gaps (no disk/DB-pool/cert alerts, no log rotation), F-04 permissionless admins can read user PII,
   F-06 `/admin/settlements/{id}/settle` has no amount/reference and settled-then-voided refunds are only logged,
   F-08 `open-in-view` still on, F-09 launch checklist unsigned.
5. Lower items F-10..F-21 (local-profile bypass and unauthenticated `/dev/2fa/reset` if run on a server, dead access-token cookie,
   shadowed `/providers/*/manage/**` rule, JWT secret length, email OTP budget, CI action SHA pinning, iOS privacy manifest, ...).

Not run on this machine (see section 6 of the report): Flutter analyze/test (SDK missing; the PATH entry `C:\flutter\src\flutter\bin`
does not exist), Android/iOS device smoke, OWASP CVE scan (needs `NVD_API_KEY`), k6, compose smoke, restore drill, provider sandbox sends.
Local tooling note: default `java` is 1.8 and `node` is 12; use JDK 17 and Node 20 (nvm), and do not run Maven and Vitest at the same time
(the Windows paging file is small and both crash).

### Fix pass (same day, after the report)

Implemented: F-01 (CI env, verified against PostgreSQL 16 + Redis), F-03, F-04, F-06, F-08 (prod/test profiles run with
`open-in-view: false`), F-10 to F-15, F-19, F-20 (privacy manifest), F-21, and most of F-02/F-07/F-18 on the repo side.
Backend `mvn test`: 404 run, 0 failures. Admin: 115 pass. `backup_test.sh`: 31 pass. Compose and Caddy configs validate.
Full status table: top of `docs/audit/production-audit-2026-10-05-r2/audit.md`.

Deploy notes for the next release:
- New REQUIRED `.env` value `OFFSITE_REMOTE` plus `deploy/secrets/rclone.conf` (compose refuses to start without them); see
  `docs/runbooks.md` "Backups off the server". Optional: `DEADMAN_WEBHOOK_URL`, `OFFSITE_HEARTBEAT_URL`, `ADMIN_ALLOWED_IPS`.
- The backend now gets only an explicit list of variables from `.env` (`docker-compose.prod.yml`); a custom variable you added
  to `.env` must be added to that list.
- Every admin needs 2FA enrolled; changing a user's email/phone is SUPER_ADMIN only; `/admin/settlements/{id}/settle` needs
  `expectedAmount` and `reference` (the panel does not call it).
- Check on staging: `open-in-view: false` in prod (`application-prod.yml`), then the k6 smoke.

Still open: F-02 operations (bucket, key escrow, restore drill), F-17 forced password change,
F-18 SHA pinning and `NVD_API_KEY`, F-09 signed `docs/launch-signoff.md`, and the tests that cannot run here (Flutter, devices, k6,
compose smoke, provider sandboxes, macOS iOS build).

Launch recommendation: staging yes; production not yet (F-02 operations, F-09 sign-off and the unrun tests first).

## Verification Completed

Backend tests were run with JDK 17:

```text
mvn test
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot
Result: BUILD SUCCESS
Tests run: 384, Failures: 0, Errors: 0, Skipped: 0
Finished: 2026-10-05T10:47:24+03:00
```

Notes:

- Offline Maven could not run because the Spring Boot 3.5.16 parent POM was not cached.
- Maven under the default Java failed because the default runtime was Java 8.
- Re-running with JDK 17 succeeded.

## Production Readiness Summary

Current recommendation:

- Staging: acceptable after configuring real provider secrets and environment values.
- Production: not yet. Operational launch gates remain open.

No new confirmed critical code vulnerability was found in the pass. The main remaining launch blockers are operational and security-control enforcement issues.

## Remaining Launch Blockers

1. Off-server disaster recovery is documented but not enforced by the deployment.
   - Local PostgreSQL data uses a Docker volume.
   - Backup container writes to local `deploy/backups`.
   - Runbook recommends `rclone`, but production readiness needs evidence of automated off-server sync and a successful restore from that off-server copy.

2. Sensitive-at-rest encryption is optional unless deployment operators set the keys.
   - `TOTP_ENCRYPTION_KEY` missing only logs a production warning.
   - `DOCUMENT_ENCRYPTION_KEY` controls private document encryption; without it, private files are stored plaintext.
   - `BACKUP_KEY_FILE` controls backup encryption; without it, alerts fire but backup still runs plaintext.

3. Admin tokens are stored in `localStorage`.
   - The admin dashboard has a strong CSP, but token theft is still possible after any future XSS, malicious extension, or compromised browser profile.
   - Prefer HttpOnly Secure SameSite cookies or a BFF session model.

4. `spring.jpa.open-in-view` remains enabled.
   - This is intentionally documented in `application.yml`, but it keeps database connections open for whole requests and should be retired before higher traffic.

5. Redis-backed throttles fail open in selected paths.
   - OTP and revocation behavior are safer than before, but login/account action throttling weakens during Redis outage.
   - Add alerting and decide if any admin-critical throttles should fail closed.

6. `docs/security-review.md` still has unresolved launch decisions.
   - SUPPORT 2FA scope.
   - Token lifetimes.
   - Encryption key setup.
   - SUPER_ADMIN holders.
   - `ADMIN_PASSWORD` removal after bootstrap.
   - Rate-limit numbers.
   - Audit-log review cadence and incident ownership.

## Lower Priority Cleanup

- Update `aiwa-backend/.env.example` so the Firebase credential variable matches current `GOOGLE_APPLICATION_CREDENTIALS` usage.
- Replace raw Spring `PageImpl` API JSON with a stable page DTO.
- Clean up minor debug/test output.

## Suggested Next Steps

1. Add production guardrails for `DOCUMENT_ENCRYPTION_KEY`, `TOTP_ENCRYPTION_KEY`, and backup encryption, or record explicit signed launch waivers.
2. Automate off-server backup sync and run a restore drill from the off-server copy.
3. Run the unexecuted gates: admin tests/build/audit, Flutter analyze/test, Android/iOS smoke, k6 smoke, restore drill, and provider sandbox checks.
4. Close the open security-review checklist with dated owner decisions.
5. Open implementation tickets for admin session storage and disabling `open-in-view`.
## Security Audit 2026-10-05

Dedicated security audit artifact added:

- `docs/audit/security-audit-2026-10-05/security-audit.md`

Additional findings beyond the production-readiness report:

- Production hardening is not fully fail-closed if a manual deploy sets a custom JWT secret but forgets `SPRING_PROFILES_ACTIVE=prod`.
- Some admin read/export endpoints expose finance/audit/booking data to any `ADMIN` role rather than narrower permissions.
- `aiwa-backend/hs_err_pid30992.log` is tracked and should be removed/ignored.
- Mobile release builds should fail when `API_BASE_URL` is missing or non-HTTPS.


## Security fixes implemented (2026-10-05, after the audit)

Done: S-01 fail-closed prod guard (`ProductionGuardConfig`, all profiles but local/test); S-02 required TOTP/document keys
(backend) and backup key (compose + `backup.sh`); S-05 narrowed admin read/export RBAC (+ nav gating); S-06 crash log untracked
and ignored; S-07 in-process rate-limit fallback + `RateLimitRedisUnavailable` alert; S-08 stricter release API-base guard + CI
check; S-09 OWASP Dependency-Check CI job (needs `NVD_API_KEY` secret); S-10 env docs; S-11 logging hygiene.
Partial: S-04 admin tokens still in localStorage, idle sign-out added, migration plan in `docs/admin-session-hardening.md`.
Not done (operational): S-03 off-server backup and restore drill.
Not run here: Flutter analyze/test (Flutter not installed on this machine), the CVE scan itself (needs the NVD key).
Deploy note: existing deployments must add TOTP_ENCRYPTION_KEY, DOCUMENT_ENCRYPTION_KEY and BACKUP_KEY_FILE before upgrading.

### F-05 done (admin session cookie)

Admin refresh token is now an HttpOnly, Secure, SameSite=Strict cookie (`aiwa_admin_refresh`, path `/api/auth`); the access
token is memory-only; `localStorage` keeps only a non-secret session hint. Cookie refresh needs `X-Requested-With: aiwa-admin`.
Backend: 410 tests pass (incl. `AdminRefreshCookieApiTest`); admin: 120 tests pass; checked in a real browser (sign-in, reload
restore, CSRF 403, logout then 401). Details: `docs/admin-session-hardening.md`. Deploy note: admins sign in once more after the
upgrade; admin and API must stay on the same registrable domain.
