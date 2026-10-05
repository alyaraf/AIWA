# AIWA Handoff

Last updated: 2026-10-05 10:50 Africa/Cairo

Project path: `D:\AIWA PROJECT\AIWA`
Branch: `main`
Audited commit: `410495a` (`System audit fixes SA-01 to SA-15: MFA scope, OTP receipt, restore safety, and more`)
Git state at audit time: `main...origin/main`, with `HANDOFF.md` untracked locally before this refresh.

## Current State

A full production-readiness audit was performed against the current repository. The stale handoff content from the older `fix/qa-round` branch no longer matched the codebase: current `main` already contains many of the high-risk fixes it listed as open.

New audit artifact:

- `docs/audit/production-audit-2026-10-05/audit.md`

No application code was changed during this audit pass. Documentation was updated only.

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
