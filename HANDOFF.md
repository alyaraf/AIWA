# AIWA Handoff - security audit 2026-10-06 remediation (newest)

Last updated: 2026-10-06, uncommitted in the tree. **Read first:** [docs/audit/security-audit-2026-10-06/remediation.md](docs/audit/security-audit-2026-10-06/remediation.md).
SEC-01 (database settles every Redis miss), SEC-02 (logout 503 unless the revocation row is confirmed), SEC-03 (one-time, expiring, attempt-limited 2FA enrollment, migration V35, per-IP limit) and SEC-04 (request ownership checked before dispatch, explicit-credential flag for clean-up requests) are fixed on the host; Tomcat 10.1.60 and JJWT 0.13.0 are in; Spring Security stays 6.5.11 (DPoP advisory not reachable, fix enterprise-only).
Validation: backend 532 pass, dashboard 237 pass + build, Flutter analyze clean, full Flutter suite 275 pass. Launch sign-off now has gates 49-53 added (53 unsigned in total beyond the earlier ones); no real PostgreSQL/Redis/device/container/CI evidence exists. Not a production-readiness claim.

---

# AIWA Handoff — round 6 remediation (current)

Last updated: 2026-10-06. Project: D:/AIWA PROJECT/AIWA; branch main. Base commit b2d70b9; the remediation below is **uncommitted work in the tree** (review the diff, commit in your own grouping).

**Read first:** [remediation record](docs/audit/production-audit-2026-10-06-r6/remediation.md) (root cause, files, tests, limits per finding), then the round 6 [audit](docs/audit/production-audit-2026-10-06-r6/audit.md) and its [validation fixtures](docs/audit/production-audit-2026-10-06-r6/validation/README.md). The audit folder is historical evidence and was not edited; its fixtures still assert the original defects.

**Production: not established.** All three round 6 findings are fixed and tested on the host, but launch sign-off still has **48 rows with no owner/decision/evidence** (45 earlier + new gates 46-48), and every real-environment check is unavailable here (no Docker engine, psql, promtool, devices, staging or cloud access).

| ID | Status | Fix |
| --- | --- | --- |
| R6-01 High | Fixed (host/fake-docker); real-container drill = gate 46 | `deploy/restore.sh`: recovery marker `backups/safety/.recovery-incomplete`, written before any backend stop, removed only when the backend is started on a proven-consistent pair. A run that finds it keeps the backend stopped on every failure (safety dump, verification, encryption, store, database half, swap) and never prints "pair intact"/start guidance; database-only runs leave it stopped; completing both halves starts it once. |
| R6-02 Medium | Fixed (host); device check = gate 47 | Flutter: `SessionOwner(generation, attempt)` on requests, `SessionEvent` on `ApiClient.authEvents`, stale 423/role-403 dropped at the mapper, owner re-checked at consumption (`routeSessionEvent`) and inside `AuthBloc` (`AuthLogoutEvent(owner:)`, `applied`); redirect only after the logout was applied. |
| R6-03 Medium | Fixed (host); real-browser check = gate 48 | Dashboard `api.safetyPage`: global oldest-open read no longer depends on the match count (skipped only for an empty unfiltered queue or an unfiltered first page holding the whole queue); closing the bannered alert clears the banner. |
| Follow-up | Fixed + measured | Chat-report / reported-review queues fetched each row's target one by one: statements for 3 vs 20 rows were 12/64 (chat) and 15/84 (reviews), now 5/6 and 5/6 (one batched query). H2 statement counts only. |

**Final verification (2026-10-06)**

| Check | Result |
| --- | --- |
| Backend (JDK 17, offline Maven) | **507 tests**, 0 failures/errors/skips (506 + 1 new query-count test; one existing unit test's stub moved to the batched lookup). Needs `-DargLine="-Xmx640m -XX:MaxMetaspaceSize=320m -Xss512k"` on this machine: two uncapped runs died with native-memory exhaustion (JVM crash, not test failures). |
| Dashboard | **236 tests / 34 files** (221 + 15 new), production build passes |
| Flutter | analyzer clean, **265 tests** (253 + 12 new) with `--concurrency=2` (default parallelism stalls this machine; every file passes alone) |
| `deploy/restore_flow_test.sh` | **93** assertions (67 + 26 new; 15 of them fail against the old script) |
| `backup_test.sh` / `uploads_swap_test.sh` | 47 / 83 |
| `restore_test.sh` | **not run** (needs Docker) |
| CI graph check | OK, 5 mutations rejected (static, not a CI run) |
| `npm audit --omit=dev --audit-level=high` | 0 vulnerabilities |
| New dashboard tests on the old source | 6 of 15 fail (red before, green after). Flutter R6-02 tests use the new API and cannot compile against the old code; the audit fixture shows the original defect. |

**Still open (external):** real PostgreSQL/Redis and V34 rehearsal, plans/statement counts on staging-sized data (gates 27, 40, 44), real-container recovery and Linux modes (24, 36, 43, 46), native account switch and device checks (17, 30, 38, 41, 47), real-browser checks (29, 37, 48), actual CI/dependency scan/release artifacts (1, 20, 34, 35, 45), providers, monitoring/alert delivery, offsite/IAM/key escrow (2-5, 15, 21, 26, 28, 39). I-03 stays mitigated, not resolved: dump and uploads are still two snapshots. After an incomplete recovery finished by hand, remove the marker only once the pair is verified. No deployment, live restore, external message or cloud change was made.

Tooling: JDK17 C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot; Node20 C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter, PUB_CACHE D:/tools/pubcache. Do not run full Maven and Vitest together; no python (use Node for patching; Dart/Java/doc files are CRLF). Do not reproduce recovery fixtures against live data.

---

## Previous handoff — round 6 verification (superseded)

### Round 6 verification (as audited)

Last updated: 2026-10-06. Project: D:/AIWA PROJECT/AIWA; branch main. Verified application commit: **b2d70b93399ac318d4aa7ce83533f9d6bf485827**. The six round 5 remediation commits are committed; the application working tree was clean throughout this audit. This delivery adds documentation and this handoff only. The preceding remediation's statement that changes are uncommitted is historical and superseded.

**Read first:** [round 6 audit](docs/audit/production-audit-2026-10-06-r6/audit.md), [closure reconciliation](docs/audit/production-audit-2026-10-06-r6/remediation-status.md), [coverage](docs/audit/production-audit-2026-10-06-r6/coverage.md), [fresh evidence and fixtures](docs/audit/production-audit-2026-10-06-r6/validation/README.md). Prior audit/remediation sections are history.

**Production: not ready.** The four original R5 scenarios are addressed in reviewed local source/tests. Six remaining admin queues now use server paging/search. Three further reproducible cases remain: **1 High, 2 Medium**. Broader M-01 and I-02 closure remains partial, AD-13 has an oldest-SOS search edge case, and I-03/I-05 external consistency/offsite evidence remains open. All **45 launch-signoff evidence rows** remain incomplete.

| ID | Priority | Required work |
| --- | --- | --- |
| R6-01 | High | An unsuccessful undo retry starts backend after a failed safety copy even when a previous failed undo left old DB/new uploads. Keep incomplete recovery stopped; qualify safe-start guidance and preserve recovery artifacts. Actual scripts/fake Docker reproduction. |
| R6-02 | Medium | Delayed account A HTTP 423 reaches the unowned global status stream and logs out current B. Extend session ownership to failed responses and event consumption. Actual client/repository/storage/bloc reproduction; native navigation is source-reviewed. |
| R6-03 | Medium | Zero-match SOS search suppresses the global oldest-open request/banner despite an unrelated open alert. Read global oldest independently of match count. API helper reproduction and render source. |

Original fixes retained: credential refresh writes/conditional clears share the lock; backup references come from the actual dump's scratch restore; successful paired undo starts only after both halves; clean lock resolution is source-map-js 1.2.2. See the closure table for their platform/staging limits and the new edge cases.

Fresh verification: backend **506 tests** (H2), dashboard **221 tests / 33 files + build**, Flutter **analyzer clean / 253 tests**; backup/swap/restore **47/83/67** assertions; CI static graph passes and **5** bad mutations rejected. Three independent defect probes confirm the new findings (extended retry harness 69 assertions, Flutter 1, dashboard 1). **691 tracked snapshot inputs** match the project. Approved fresh public npm production advisory check: **0 reported vulnerabilities**, exit 0. Passing defect probes assert faulty behavior, not fixes.

Docker Linux engine pipe remains absent; psql/promtool are unavailable. Real PostgreSQL/Redis, production-copy V34 rehearsal, Linux modes/container recovery, actual CI, native browser/device/release archives, provider delivery, cloud/offsite/key escrow and load remain unverified. Gates 41–45 specifically track the recent remediation's external evidence; no row is closed by these local checks.

No application fixes, dependency updates, live restores, deployment, external messages or cloud mutations were performed. The dependency-only public scan used the user's existing authorization; no further approval is needed for that completed check.

Audit workspace: C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r6. Tooling: JDK17 C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot; Node20 C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter, PUB_CACHE D:/tools/pubcache. Do not run full Maven and Vitest together. Do not reproduce recovery fixtures against live data.

---

## Previous handoff — round 5 remediation (superseded)

# AIWA Handoff — round 5 remediation (current)

Last updated: 2026-10-06. Project: D:/AIWA PROJECT/AIWA; branch main. Audit baseline ddebaf9; the remediation is **uncommitted work in the tree** (review the diff, commit in your own grouping).
**Read first:** [round 5 remediation record](docs/audit/production-audit-2026-10-06-r5/remediation.md) (status of every item, design, tests, limits, changed files). The round 5 audit files and the previous sections below are history.

**Production: not ready.** All four R5 findings and the six-queue paging follow-up are implemented and tested locally; every item that needs a real environment is still open (launch sign-off now has **45 open rows**, 41-45 are new).

| ID | Status | What changed (details in the record) |
| --- | --- | --- |
| R5-01 refresh corrupts a newer session | fixed (host tests); iOS device evidence open (gate 41) | `SecureStorage.storeRefreshedTokens` / `clearIfSession`: refresh writes and refresh-failure clears run inside the credential lock and re-check the session there; logout/sign-in already used the lock. 7 new regression tests (delayed access/refresh write, logout, rejected refresh, next request is B's). |
| R5-02 reconciliation reads the live DB | fixed (stub DB); real PostgreSQL rehearsal open (gate 42) | `backup.sh` reads the references from the dump's own scratch restore; failed/incomplete scans stay "failed", never zero missing. Still two snapshots; limits documented in the runbook. |
| R5-03 undo restarts the backend between halves | fixed (fake Docker); real-container drill open (gate 43) | `./restore.sh --undo <id>`: preflight both halves, stop, previous DB, uploads rollback, start only after both; either failure keeps it stopped with runnable commands. `uploads_swap.sh status` added. |
| R5-04 source-map-js | fixed locally; CI run open (gate 45) | lockfile only: 1.2.2; `npm audit --omit=dev --audit-level=high` = 0 vulnerabilities; CI gate unchanged. **Please review the registry note in the record** (the lockfile URL of that one package was rewritten from this machine's internal mirror to registry.npmjs.org). |
| AD-13 six queues | fixed in code/H2/jsdom; PostgreSQL scale evidence open (gate 44) | Verification, Photo moderation, Chat reports, Reported reviews, Settlements, SOS are server-searched/paged with real totals. SOS keeps its ordered-read rule and reads the oldest open alert separately. Deliberate behaviour changes are listed in the record. |

Fresh verification: backend **506 tests** (was 498, H2), dashboard **221 tests / 33 files + build** (was 193 / 32), Flutter **analyzer clean / 253 tests** (was 246), backup/swap/restore-flow **47/83/67** checks (were 41/79/45), CI graph + 5 rejected mutations. No test was weakened; the few adapted tests are listed in the record.

Still unverified (no prerequisites here): PostgreSQL/Redis, V34 on production-sized data, real-container restore/undo, Linux modes, promtool, CI run, native browsers, devices (gate 41), provider sandboxes, cloud/offsite/key escrow, load. Docker's Linux engine is still unavailable and there is no psql. No deployment, live restore, external message or cloud change was made.

Tooling: JDK17 C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot (`mvn -B -o`); Node20 C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter, PUB_CACHE D:/tools/pubcache. Do not run full Maven and Vitest together. Edit CRLF files through a line-ending-preserving patch (the Write tool for scripts: bash heredocs eat backslashes).

---

## Previous handoff — round 5 verification (superseded by the remediation above)

# AIWA Handoff — round 5 verification

Last updated: 2026-10-06. Project: D:/AIWA PROJECT/AIWA; branch main. Verified application commit: **ddebaf9e40d7fd1a071888a490aea23715e6d2bd**. The six round 4 remediation commits are committed; the application working tree was clean throughout verification. This delivery adds audit documentation and this handoff only.

**Read first:** [round 5 audit](docs/audit/production-audit-2026-10-06-r5/audit.md), [closure reconciliation](docs/audit/production-audit-2026-10-06-r5/remediation-status.md), [coverage](docs/audit/production-audit-2026-10-06-r5/coverage.md), [fresh evidence and fixtures](docs/audit/production-audit-2026-10-06-r5/validation/README.md). Earlier audit/remediation records are history.

**Production: not ready.** The original eight R4 scenarios are addressed and their local regression suites pass, but four actionable R5 items remain (1 High, 3 Medium at repository scope). The dependency's upstream advisory is High; production exploitation was not established. M-01 and I-02 remain partial, I-03's new clean-pair diagnostic is incomplete, AD-13 covers only 3 of 9 server-paged queues, and external offsite/cloud evidence is still missing. All 40 launch-signoff evidence rows remain incomplete.

| ID | Priority | Required work |
| --- | --- | --- |
| R5-01 | High | Refresh bypasses the credential lock; a delayed A write can corrupt B's stored session. Serialize session-owned writes/clears. Host reproduction models out-of-order storage; locked iOS plugin uses a concurrent queue. Android uses a serialized worker; native iOS proof remains open. |
| R5-02 | Medium | Backup-time reconciliation queries the later live DB, not the saved dump; a deleted reference/file falsely yields zero missing. Extract references from the actual dump snapshot. |
| R5-03 | Medium | Printed DB-first whole-restore undo restarts backend before previous uploads are restored. Provide coordinated undo that starts only after both parts succeed. |
| R5-04 | Medium | source-map-js 1.2.1 via Vite/PostCSS has a High upstream advisory and fails the current mandatory npm audit. Refresh the affected resolution to patched 1.2.2 or compatible later version; rerun audit/tests/build. It is a build-chain finding; no dashboard-user exploit was established. |

Fresh verification: backend **498 tests** (H2), dashboard **193 tests / 32 files + build**, Flutter **analyzer clean / 246 tests**; backup/swap/restore-flow **41/79/45** checks; CI graph **5 rejected mutations**. Three deterministic code probes reproduce R5-01/02/03; their success asserts defects, not fixes. **687 tracked snapshot inputs** match the project. The approved fresh public npm scan found **1 High upstream advisory** (CVE-2026-93749), superseding the prior zero-advisory record.

Docker Linux engine named pipe is still absent; psql/promtool not found. Real PostgreSQL/Redis, production-copy V34 rehearsal, Linux modes/container recovery, CI, native browser/device, provider delivery, cloud/offsite and load remain unverified. The earlier cross-tab browser evidence used a simulated storage event; it does not close genuine two-tab gate 37.

No application fixes, dependency updates, live restores, deployments, external messages or cloud mutations were performed. The npm metadata check was initially blocked by automatic review, then explicitly authorized by the user and completed. No remaining approval is needed for that completed check.

Audit workspace: C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r5. Tooling: JDK17 C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot; Node20 C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter, PUB_CACHE D:/tools/pubcache. Do not run full Maven and Vitest together. Local audit builds are not native release evidence.

---

## Previous handoff — round 4 remediation (superseded)

# AIWA Handoff — round 4 remediation (current)

Last updated: 2026-10-06. Project: D:/AIWA PROJECT/AIWA; branch main. Audit baseline 290a05f; the remediation is **uncommitted work in the tree** (review the diff, commit in your own grouping).

**Read first:** [remediation.md](docs/audit/production-audit-2026-10-05-r4/remediation.md) (every finding and follow-up: status, cause, change, files, tests, compatibility, what is still open). The round 4 [audit](docs/audit/production-audit-2026-10-05-r4/audit.md) and [status table](docs/audit/production-audit-2026-10-05-r4/remediation-status.md) are history.

**Production: not ready.** R4-01…R4-08 fixed and tested locally; follow-ups fixed or mitigated (server paging done for 3 of 9 queues). Launch sign-off now has 40 open rows (35–40 are new); nothing that needs a real environment was run.

Verified here: backend, dashboard (193 tests), Flutter (analyze clean, 246 tests), backup/swap/restore-flow shell suites, CI graph check, V34 rehearsal on H2, and a real-browser two-account check of R4-03 against the local backend (numbers in the remediation record).
Blocked: Docker Desktop's Linux engine will not start here and there is no PostgreSQL/promtool, so real-PostgreSQL migration and concurrency, promtool, container restore, CI, devices, providers, offsite and load are all unverified.

Operational notes for the next deploy: new optional env vars BACKUP_SAFETY_KEEP_DAYS, SMS_RECEIPT_FIELD, EMAIL_RECEIPT_FIELD (the compose pass-through list was extended); the backup container mounts uploads_references.sql; restore safety copies now live encrypted in deploy/backups/safety (old plaintext deploy/backups/pre-restore-*.dump files are not touched, delete them after checking); the admin sidebar shows only unrestricted screens until /auth/me answers; SOS admin DTO has three new fields; set repository variable REQUIRE_CVE_SCAN=true before production promotion.
Tooling: JDK17 C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot (use the full path to java.exe in background jobs; PATH picks Java 8), Node20 C:/Users/fsherif/AppData/Local/nvm/v20.20.2, Flutter D:/tools/flutter with PUB_CACHE D:/tools/pubcache. Do not run Maven and Vitest together. A local backend: java -jar target/aiwa-backend-1.0.0.jar --spring.profiles.active=local (H2, seeded demo data, admin@aiwa.com); serve the dashboard from localhost (not 127.0.0.1) so the SameSite=Strict refresh cookie is sent.

---

## Previous handoff (round 4 audit; superseded by the above)

# Round 4 re-audit (history)

Last updated: 2026-10-05. Project: D:/AIWA PROJECT/AIWA; branch main.
Audited application commit: 290a05f0606545c073c22e1753cc9ad5c584fa5a.
The six remediation commits after ac67446 are committed. The application tree was clean during verification; this audit changes documentation only.

## Read this current status first

- [Round 4 audit](docs/audit/production-audit-2026-10-05-r4/audit.md): eight actionable findings with locations, reproductions and fixes.
- [Earlier findings rechecked](docs/audit/production-audit-2026-10-05-r4/remediation-status.md): 29 fixed in reviewed paths, 5 partial, 3 mitigated, 1 external.
- [Current API inventory](docs/audit/production-audit-2026-10-05-r4/api-inventory.md): 183 handlers / 29 controllers.
- [Coverage](docs/audit/production-audit-2026-10-05-r4/coverage.md), [fresh logs and fixtures](docs/audit/production-audit-2026-10-05-r4/validation/README.md).
- [Launch sign-off](docs/launch-signoff.md): all 34 evidence rows remain open.

**Production: not ready.** The earlier claim that all repository-actionable defects were fixed is superseded.

## Current priorities

| ID | Severity | Confirmed behavior |
| --- | --- | --- |
| R4-01 | High | Restore restarts backend after an OS rename failure also prevents uploads rollback |
| R4-02 | High | SOS DTO uses edited saved address instead of agreed booking snapshot |
| R4-03 | High | Cross-tab Finance session retains old restricted SOS data |
| R4-04 | Medium | Private blob body can finish after account change |
| R4-05 | Medium | Obsolete mobile auth handlers delete newer tokens or overwrite authenticated state |
| R4-06 | Medium | Retained pre-restore dump is plaintext and outside scheduled retention |
| R4-07 | Medium | Old initial/manual SOS response erases a newer poll and claims live |
| R4-08 | Low | Staging deployment waits only for backend/admin, not new recovery/monitoring checks |

## Fresh validation and remaining work

Backend 483 tests, dashboard 164 tests + build, Flutter analyzer clean / 221 tests; shell checks 32/33/23. Public npm production advisory scan reports zero vulnerabilities. Additional isolated probes reproduce R4-01 through R4-07; their assertions verify defects, not fixes.

Docker Desktop Linux engine is unavailable. Real PostgreSQL/Redis, promtool/container restore, CI, native browser, devices, providers/cloud/offsite and load were not freshly verified. Keep those gates open.

The user requested audit only; no application remediation was performed. Address High findings first, then Medium session/freshness/backup issues. Rehearse V34 on production-copy data and preserve destination_backfilled provenance. Mobile destination amendment UI and durable onboarding inputs remain follow-ups. Offsite lifecycle/IAM/escrow and all launch gates require execution evidence.

JDK17: C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot; Node20: C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter; PUB_CACHE D:/tools/pubcache.
Avoid concurrent Maven and full Vitest. Audit workspace: C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r4.

---

## Historical handoff — remediation / round 3

Preserved history below. Its uncommitted-remediation and complete-fix statements are superseded by round 4 above.

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
