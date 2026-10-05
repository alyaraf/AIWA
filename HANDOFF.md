# AIWA Handoff — current status

Last updated: 2026-10-05, after the round 3 remediation.
Project: `D:\AIWA PROJECT\AIWA`; branch: `main`. Audit baseline `ac67446495a22ce11b8f2071d0f1599f3c0cdee4`; the remediation is
**uncommitted work in the tree** (review the diff, then commit in whatever grouping you prefer).

## Read this first

- [Remediation record](docs/audit/production-audit-2026-10-05-r3/remediation.md): every finding and potential risk with status, fix,
  files, tests and what is still waiting on something external. This is the current truth.
- [Round 3 audit report](docs/audit/production-audit-2026-10-05-r3/audit.md): the original findings, kept unchanged as history.
- [Verification log](docs/audit/production-audit-2026-10-05-r3/validation/remediation-results.md): commands and results.
- [Launch sign-off](docs/launch-signoff.md): 34 gates (24–34 added by this pass), all still open. Fill in owner/date/evidence.

**Production: not ready.** The repository-actionable defects are fixed and tested; the evidence that decides launch (staging,
devices, providers, cloud, CI, load) does not exist yet. See "Production-readiness decision" in the remediation record.

## What changed (summary)

| Area | Resolved |
| --- | --- |
| Backend | B-01 image decode bounds; B-02/B-03 shared privacy projections; B-04 admin read matrix + filtered inbox; B-05 booking destination snapshot (V34) + amend endpoint; B-06 review serialization; B-07 unsave transaction; B-08 metric; I-06 log hygiene; P-01 profile mix guard; P-02 gateway URL rules; P-06 temporary-password sessions end at expiry; P-07 e-mail refusal in body; M-05 server onboarding stage; M-06 travel-buffer endpoint; CSV neutralization; API contract snapshot |
| Flutter | M-01 session-safe transport/state; M-02 live-status query; M-03 multipart replay; M-04 identity kept on transient errors; M-05 resumable provider setup; M-06 narrow buffer update; M-07 full policy shown and version pinned; M-08 deferred booking; M-09 local-notification launch; M-10/M-11 paging races |
| Admin dashboard | AD-01 CSV; AD-02 policy race; AD-03 balances; AD-04/P-03/P-04 one transport, idle limit, stale-answer guard; AD-05 SOS stale state; AD-06 refresh contract; AD-07 partial operations; AD-08 capability matrix; AD-09 hidden reviews; AD-10; AD-11 accessible dialogs and rows; AD-12 copy; AD-13 truncation notice |
| Infrastructure | I-01 disk alerts + promtool tests; I-02 staged restore with paired rollback; I-03 backup manifest + reconciliation report; I-04 local-only compose and docs; I-05 retention policy written; P-05 admin Docker guards; CI jobs for rules, backup/restore suites and SBOM |

## Validation actually completed

Backend **483** tests (baseline 411), admin **164** tests + build, Flutter **analyze clean / 221** tests, backup harness **32**,
staged-uploads failure injection **33**, restore flow **23**. A real-browser pass (mock mode) confirmed the dialog, keyboard-row
and stale-SOS behavior and found one crash that is now covered by a smoke test.

Not verified here: PostgreSQL/Redis (Docker Desktop would not start), promtool, any CI job, `npm audit` (endpoint error),
devices, providers, cloud/bucket, k6, deployed behavior. Exact reasons in the verification log.

## Open items for you (exact inputs needed)

1. **Staging deploy** of backend + dashboard together (the admin read matrix returns 403 to admins without SUPPORT; a new mobile
   build needs the new backend). Run Flyway **V34 on a copy of production data first** and read `destination_backfilled`.
2. **Docker**: start Docker Desktop (or use CI) to run `promtool test rules`, `deploy/restore_test.sh` and the compose stack;
   `docker compose up -d backup` before the first restore (new mounted scripts).
3. **Off-site bucket**: lifecycle (30 days), versioning/object lock, write-only key, escrow owners (runbooks, "Off-site retention policy"); then the
   off-site-only restore drill.
4. **Devices/browsers**: the checks in gates 29 and 30. **Providers**: SMS, e-mail, FCM sandbox sends and a real SOS route (gates 15, 21).
5. **CI**: push, confirm every job is green (including `monitoring-rules`, `backup-restore`, `sbom`), set `NVD_API_KEY`.
6. **Decisions**: the "live states only" location rule (B-02), the temporary-password session rule (P-06), whether a forced
   password change is wanted, and a mobile screen for the destination amendment API (B-05).
7. Not started on purpose (refactors / capacity work): splitting `BookingServiceImpl`, typed provider contracts, modular admin pages,
   server-side paging for the admin queues (the 50-page cap now announces itself), an HA/storage plan from measured load.

## Notes for the next developer

- Environment: JDK 17 at `C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot`, Node 20 at
  `%LOCALAPPDATA%\nvm\v20.20.2` (the default `node` is 12), Flutter `D:\tools\flutter`, `PUB_CACHE=D:\tools\pubcache`.
  Do not run Maven and Vitest at the same time on this machine.
- After a deliberate API change, regenerate the contract: `mvn test -Dtest=ApiContractSnapshotTest -Dapi.contract.update=true`
  and review the diff of `aiwa-backend/src/test/resources/api-contract/` with the mobile and dashboard changes it implies.
- Shell scripts and generated text in this repo are easy to corrupt with backslash handling in some tools; check the diff.


---

## Previous status (audit round 3, before remediation; kept as history)

Last updated: 2026-10-05, production audit round 3.
Project: `D:\AIWA PROJECT\AIWA`; branch: `main`.
Audited application commit: `ac67446495a22ce11b8f2071d0f1599f3c0cdee4`.
This audit began at `2bceba5` and incorporated the concurrent `ac67446` commit before final validation.

## Read this current status first

Complete audit artifact: [Round 3 report](docs/audit/production-audit-2026-10-05-r3/audit.md).
Supporting artifacts: [181-handler API inventory](docs/audit/production-audit-2026-10-05-r3/api-inventory.md),
[API business/ownership flows](docs/audit/production-audit-2026-10-05-r3/api-flows.md),
[coverage and validation](docs/audit/production-audit-2026-10-05-r3/coverage.md),
[dashboard evidence](docs/audit/production-audit-2026-10-05-r3/dashboard.md).

That pass changed documentation only; the remediation above was authorized afterwards.

## Launch recommendation and fresh priorities

**Production: not ready.** No confirmed Critical issue, but new High findings and operational gates remain.
Controlled staging validation is the next step; passing suites do not remove these defects.

1. **B-01 High:** public-image normalization admits extremely wide PNG scanline allocations despite subsampling;
   bounded JDK17 probe reproduced heap exhaustion. Add dimension/working-memory caps before decoding.
2. **B-02/B-03 High:** booking/alternative summaries leak an individual home provider's exact location before acceptance;
   provider dashboard exposes customer email/phone outside CONTACT_VISIBLE states. Use shared audience/state projections.
3. **B-04 High:** any ADMIN, including no-SUPPORT/Finance, can read sensitive SOS/chat/review/flag/staff data.
   This is confirmed exposure and inconsistent least-privilege scope; current broad-read annotations permit it.
   Decide and enforce a consistent read capability policy rather than assuming MFA supplies entitlement.
4. **B-05 High:** editing a saved address silently changes existing booking destination/history without radius/requote/consent.
   Store an immutable booking address snapshot and define explicit amendments.
5. **M-01 High:** successful old profile responses can cache/emit the previous identity after logout/account switch.
   Session generation must protect success/cache/Bloc state, not only refresh/401 retry.
6. **AD-05 High:** SOS polling silently swallows network/503 failures and keeps an apparently current empty list.
   Show last-sync/stale/offline state and prove actual on-call channels.
7. **I-02 High:** restore deletes live uploads before extraction; extraction failure leaves lost/partial files and stopped backend.
   Stage/verify/swap volumes with paired DB/files rollback and failure-injection tests.
8. **B-06/B-07 Medium, reproduced:** admin reviews fail lazy quickTags serialization with OSIV=false; unsave lacks a transaction.
9. Additional mobile/admin/infra findings, exact source locations, reproduction steps and P0–P3 roadmap are in the report.
   Disk alert selectors incorrectly match mountpoint /host rather than exported host labels; offsite restore/key escrow/retention,
   provider/device/release archive, CI/NVD and measured load gates still lack current operational evidence.

## Validation actually completed in this pass

All commands used an isolated audit snapshot and synthetic data; original source/build outputs were not modified.

- Backend (JDK17.0.19): **411 tests, 0 failures, 0 errors, 0 skipped**, BUILD SUCCESS.
- Admin (Node20.20.2): **120 tests / 20 files pass**, production build succeeds, npm audit **0 reported vulnerabilities**.
- Flutter installed at **D:\tools\flutter** (3.47.5, Dart3.13.4; cache D:\tools\pubcache):
  **analyze: no issues; 178 tests pass**, including English/Arabic goldens. Earlier SDK-missing note is obsolete.
- Backup fake-Docker shell harness: **31 pass, 0 fail**; NTFS permission-mode assertion skipped.
- Isolated H2 probes reproduced review/unsave failures, pending location/contact disclosure, mutable destination and broad SOS read.
- Isolated JDK image probe reproduced decoder OOM with a synthetic 66-byte PNG header, not a live API attack.

Not verified here: deployed PostgreSQL/Redis concurrency/migrations and data, actual GitHub CI/NVD/image scans,
Android/iOS devices/signed archives, real SMS/email/FCM, staging compose/rollback/k6/soak, delivered alerts,
cloud IAM/offsite-only restore/key custody/retention, new admin browser/accessibility/session ordering,
complete Git-history/ignored-secret/compiled-artifact secret scan. See coverage.md for exact boundaries and evidence.

## Historical fixes checked as present

F-05 memory-only access and HttpOnly/Secure/SameSite refresh cookie; default mandatory admin MFA; narrowed user/contact/finance/audit
controls; production encryption guards; OSIV=false in production/test; expected settlement amounts/references and payout freeze;
commission snapshots; required immutable offsite copy; local rate-limit fallback; SHA-pinned actions; V33 temporary-password expiry;
Redis/cash alerts; production APNs Release/Profile entitlement. Deployed operation is still a launch-gate check.
Expiry does not by itself force password change or shorten already-issued sessions; document that separate policy.

## Historical handoff retained below

The following content records earlier audits and implementation passes. Its old "current", "remaining" and tooling claims
must not override the round3 report or the current status above. It is retained for provenance and prior fix context.

---

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

### Remaining items pass (same day)

Done: F-17 (temporary passwords expire after 24 h, migration V33), F-18 (all GitHub Actions pinned to commit SHAs; fixed a wrong
Trivy tag), F-06 (cash-not-collected metric + alert), F-07 (RedisDown alert via redis-exporter; certificate expiry via the outside
uptime monitor), F-20 (APNs production entitlement for Release/Profile builds). Backend 411 tests, 0 failures.

Left for you (cannot be done in the repo): F-02 operations (bucket, `deploy/secrets/rclone.conf`, off-server key copies, restore
drill), F-09 signed `docs/launch-signoff.md`, the `NVD_API_KEY` repository secret, `ADMIN_ALLOWED_IPS`, staging checks
(`open-in-view: false`, k6, compose smoke), Flutter/device/iOS-archive/provider-sandbox tests. F-16 (lockout reveals an account
exists) is an accepted trade-off. New deploy note: Flyway migration V33 runs on the next start.
