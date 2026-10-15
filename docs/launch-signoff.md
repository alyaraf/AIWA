# Launch sign-off record (F-09)

One row per launch gate. A gate is closed only when it has an **owner**, a **decision**, a **date** and
**evidence** (link, log line, screenshot). Open items from `docs/security-review.md` are listed here so
nothing is left as an unticked box. Fill this in; empty cells mean the gate is open.

| # | Gate | Owner | Decision / result | Date | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | CI green on `main` (all jobs, including migrations on PostgreSQL 16) | | | | |
| 2 | Off-server backup running (`dc logs offsite` says `offsite ok`) | | | | |
| 3 | Restore drill from the off-server copy with escrowed keys (runbooks, "Restore drill") | | | | |
| 4 | Keys escrowed off the server: `BACKUP_KEY_FILE`, `DOCUMENT_ENCRYPTION_KEY`, `TOTP_ENCRYPTION_KEY`, `JWT_SECRET` | | | | |
| 5 | Bucket versioning / object lock on, write-only key on the server | | | | |
| 6 | Who holds SUPER_ADMIN at launch (at least two people) | | | | |
| 7 | `ADMIN_PASSWORD` removed from `deploy/.env` and the backend recreated | | | | |
| 8 | Every admin has 2FA enrolled (enforced by the backend, check the user list) | | | | |
| 9 | `ADMIN_ALLOWED_IPS` set to the office / VPN ranges (or a written waiver) | | | | |
| 10 | Token lifetimes confirmed (access 15 min, refresh 7 days, admin refresh 8 h) | | | | |
| 11 | Rate-limit and OTP budget numbers fit expected traffic | | | | |
| 12 | Audit log (`/admin/audit`) reviewer and cadence | | | | |
| 13 | Admin offboarding: deactivate the same day (sessions end at once) | | | | |
| 14 | Incident contact for a suspected account takeover (added to `docs/runbooks.md`) | | | | |
| 15 | Alert delivery tested: email/Telegram, dead-man's switch (`DEADMAN_WEBHOOK_URL`), `HostDiskLow` on staging | | | | |
| 16 | Flutter analyze/test green in CI; signed release AAB built with `tool/build_release.sh` | | | | |
| 17 | Android and iOS device smoke test (sign-up OTP, booking, push, deep link, SOS text) | | | | |
| 18 | iOS archive checked: `aps-environment` is `production`, `PrivacyInfo.xcprivacy` is in the Runner target | | | | |
| 19 | k6 smoke (`deploy/loadtest/smoke.js`) and production compose smoke on staging | | | | |
| 20 | `NVD_API_KEY` set and the `dependency-scan` job green | | | | |
| 21 | Provider sandbox checks: SMS, email, FCM | | | | |
| 22 | `open-in-view` decision (documented traffic ceiling, or disabled and load tested) | | | | |
| 23 | Admin session storage decision (cookie/BFF migration, or accepted risk with 2FA + idle timeout) | | | | |
| 24 | Staged restore drill on staging: normal restore, then fill the uploads volume / kill the extraction and confirm the live files, database and backend end up as before (runbooks, "Restoring") | | | | |
| 25 | After a restore from a live system, the reconciliation report (`reconcile:` line of `restore.sh`) was read and any MISSING files explained | | | | |
| 26 | `monitoring-rules` CI job green and `HostDiskLow` fired and was delivered on staging (the disk selector is now `mountpoint="/"`, audit I-01) | | | | |
| 27 | Migration V34 (booking destination snapshot) rehearsed on a copy of production data: row counts, `destination_backfilled` share, app rollback to the previous release | | | | |
| 28 | Off-site policy approved and configured in the bucket: expiry (default 30 days) and versioning/object lock, least-privilege keys, key escrow owner (runbooks, "Off-site retention policy") | | | | |
| 29 | Admin dashboard checked in real browsers: session end/idle across tabs, logout then login ordering, screen-reader pass of dialogs and Bookings (audit AD-04, AD-11, P-03, P-04) | | | | |
| 30 | Mobile checked on Android and iOS devices: account switch with a slow network, expired-token upload, kill during provider onboarding then resume, local-notification cold launch (audit M-01, M-03, M-05, M-09) | | | | |
| 31 | Admin read matrix verified on staging with enrolled accounts: no permission, Finance, Support, Super admin against SOS, reported chat, reviews, flags, staff, inbox (audit B-04) | | | | |
| 32 | Resolved production configuration printed on staging: active profiles contain only `prod`, gateway URLs are public https (audit P-01, P-02) | | | | |
| 33 | Temporary-password session policy accepted: a session started with a temporary password ends when it expires (audit P-06) | | | | |
| 34 | SBOM artifact produced by CI and kept with the release (roadmap P3) | | | | |
| 35 | `release-gate` job green on `main` and `deploy-staging` started only after it; repository variable `REQUIRE_CVE_SCAN=true` set before any production promotion; the gate summary shows the CVE scan as "ran", not "skipped" (audit R4-08) | | | | |
| 36 | Safety-copy drill on staging: a restore leaves `backups/safety/pre-restore-<id>.dump.enc` (encrypted, mode 600), the disk-space refusal and the "RECOVERY FAILED, backend stays STOPPED" path are rehearsed on a real volume, `BACKUP_SAFETY_KEEP_DAYS` pruning observed (audit R4-01, R4-06) | | | | |
| 37 | Admin two-tab check in real browsers with real cookies: Super admin with SOS rows loaded, sign in as Finance in a second tab, the first tab drops the rows; a document or export download started before logout produces nothing (audit R4-03, R4-04) | | | | |
| 38 | Mobile on devices: slow sign-in overtaken by a second one, cold start with "remember me" off racing a sign-in, destination change of an accepted home visit, provider sign-up killed after the profile step and resumed from the checkpoint, policy changed during sign-up with the reload failing (audit R4-05 and follow-ups) | | | | |
| 39 | `SMS_RECEIPT_FIELD` / `EMAIL_RECEIPT_FIELD` set from the provider sandbox answers (or a written waiver) so a 2xx without a receipt is not "accepted" | | | | |
| 40 | Complaints, Flags and Reviews queues checked against staging-sized data: server paging, search, totals, and statement counts (audit follow-up, admin queue paging) | | | | |
| 41 | iOS device: account A's token refresh in flight while account B signs in (and while signing out / a refresh is rejected); afterwards B's access token, refresh token and user id belong together and the next request is B's. Host tests only model the delayed writes; the locked iOS secure-storage plugin uses a concurrent queue (audit R5-01) | | | | |
| 42 | Real PostgreSQL + uploads volume: a file referenced by the dump is deleted (with its row) before the uploads are archived and the backup manifest still reports it missing; a killed scratch query reports `reconcile: failed`, never zero missing (audit R5-02) | | | | |
| 43 | Real containers: `./restore.sh --undo <id>` after a restore with uploads: backend stopped for both halves, started only when the previous database and uploads are both back; failure of either half leaves it stopped with the printed commands working; encrypted safety copy decrypts (audit R5-03) | | | | |
| 44 | The verification, photo moderation, chat report, reported-review, settlement and SOS queues checked against staging-sized PostgreSQL data: server paging, search, status filters, totals, ordering, statement counts and plans; the oldest open SOS is shown whatever page is open (audit R5 follow-up, AD-13) | | | | |
| 45 | `dashboard` CI job green on the committed lockfile (`npm ci --ignore-scripts`, `npm audit --omit=dev --audit-level=high`, tests, build) with source-map-js 1.2.2 or later (audit R5-04) | | | | |
| 46 | Real containers: retry of an undo whose uploads half failed, with the failure injected at the safety dump, its verification, encryption and storage, and at the database half: the backend stays stopped each time, `backups/safety/.recovery-incomplete` is present, both data generations and every recovery artifact are unchanged, and a clean retry finishes both halves, starts the backend once and removes the marker. Host evidence: `deploy/restore_flow_test.sh` cases R6* (fake docker); the real-volume run is still required (audit R6-01) | | | | |
| 47 | Android and iOS devices: account A's request returns 423 / role 403 after account B signs in, and while B's sign-in is still waiting for the server; B stays signed in, no Account locked or Forbidden screen, B's next request is B's. Then the current-session cases: a locked account still reaches Account locked and a wrong-role call still reaches Forbidden. Host evidence: `test/core/session_event_ownership_test.dart`, which drives the real client, repository, storage, bloc and event routing but not the native router or secure storage (audit R6-02) | | | | |
| 48 | Admin dashboard in a real browser against staging data: a search with no match in the SOS queue still shows the oldest-open banner for an unrelated alert; an empty queue shows none; Resolved shows none; closing the oldest alert moves the banner to the next. Host evidence: `src/test/Safety.oldest.test.jsx` against a fake server (audit R6-03) | | | | |
| 49 | Real PostgreSQL + Redis + two backend instances: log out (access and refresh token), then flush/restart Redis; the revoked access token is refused on both instances; stop PostgreSQL then log out: 503 `auth.error.logout_revocation_failed` and the client still signs out locally; k6 comparison of authenticated-request latency before/after the per-request `revoked_tokens` lookup. Host evidence: `TokenRevocationRegressionTest` with fake stores (audit SEC-01, SEC-02) | | | | |
| 50 | Staging: migration V35 applied; 2FA setup then enable works; the sixth wrong code is 429 from different IPs and with Redis stopped; an enabled account gets `auth.error.totp_already_enabled` and no session; an enrollment older than 10 minutes is refused. Host evidence: `TotpEnrollmentApiTest` (audit SEC-03) | | | | |
| 51 | Android and iOS devices: account A starts a profile edit / upload with the secure-storage read delayed, B signs in (and: A signs out; another sign-in starts); the backend never sees a request from A under B's token, and A's sign-out revocation still reaches the server. Host evidence: `test/core/request_ownership_test.dart`, not native secure storage (audit SEC-04) | | | | |
| 52 | Backend dependency evidence: OWASP Dependency-Check with `NVD_API_KEY` (and `REQUIRE_CVE_SCAN=true`), Trivy image scan, Dart advisory check and OS patch status recorded; the running container reports Tomcat 10.1.60 and JJWT 0.13.0; behind Caddy no HTTP/2, AJP or WebSocket reaches Tomcat; written acceptance that Spring Security 6.5.11 (DPoP advisory CVE-2026-41707, not reachable) stays until the Spring Boot 4 upgrade | | | | |
| 53 | Smoke after the JJWT/Tomcat upgrade on staging: login, refresh rotation, admin 2FA verify, logout and cutoff-based session end (password reset) with real tokens | | | | |
| 54 | Staging (RV-03): `bash deploy/deploy.sh` takes the pre-deploy backup (a failing one refuses the deploy), then `bash deploy/deploy.sh --rollback` starts the previous release without a build and the API is healthy; then a code-and-database rollback via `restore.sh` with the pre-deploy dump. Host evidence: `deploy/deploy_test.sh` (fake docker/git) | | | | |
