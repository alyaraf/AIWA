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
