# Round 4 remediation record

Date: 2026-10-06 (work started 2026-10-05). Audit baseline: commit `290a05f`; the work is **uncommitted in the tree**. The original
[audit.md](audit.md) and [remediation-status.md](remediation-status.md) are kept unchanged as history. Environment: Windows, JDK 17.0.19,
Node 20.20.2, Flutter 3.47.5 / Dart 3.13.4, Git Bash. **Docker Desktop's Linux engine does not start here and there is no PostgreSQL or promtool on the machine**
(details in "Blocked by the environment").

Status vocabulary: **fixed** = the defect is closed in code and the tests listed pass; **mitigated** = materially reduced, a stated part remains;
**blocked** = needs an input or environment that is not available here. "Fixed" never means deployed or device-verified: that evidence is in the
launch sign-off gates, all still open.

## Summary

| ID | Title | Status |
| --- | --- | --- |
| R4-01 | Restore rollback errors ignored | fixed |
| R4-02 | SOS uses the editable saved address | fixed |
| R4-03 | Cross-tab account change keeps restricted data | fixed (also checked in a real browser against a real backend) |
| R4-04 | Private blob bodies escape the session check | fixed |
| R4-05 | Obsolete mobile auth operations | fixed |
| R4-06 | Plaintext safety backup outside retention | fixed |
| R4-07 | SOS request ordering and freshness | fixed |
| R4-08 | Staging deploy ignores new checks | fixed |
| FU-1 | Mobile destination amendment | fixed |
| FU-2 | Durable provider onboarding | fixed (device kill/relaunch evidence outstanding) |
| FU-3 | Backup strategy and reconciliation | mitigated (still two snapshots, now proven and reported) |
| FU-4 | Server-driven admin queues | mitigated (Complaints, Flags, Reviews done; six queues remain loaded lists) |
| FU-5 | Newer-policy reload UX | fixed |
| FU-6 | Integration contract, maintainability, performance | mitigated (receipt contract and an N+1 fix done; refactors deferred) |
| FU-7 | Recheck of the 38 earlier findings and the potential risks | done, table at the end |

## Validation results (this machine, after the changes)

| Suite | Result |
| --- | --- |
| Backend, JDK 17, offline Maven | **498 tests, 0 failures, 0 errors, 0 skipped** (was 483), BUILD SUCCESS; H2 only |
| Dashboard Vitest | 193 tests / 32 files pass (was 164 / 28); production build succeeds (349.53 kB JS, 102.00 kB gzip) |
| Flutter `analyze` / `test` | analyzer clean; 246 tests pass (was 221), including the English/Arabic goldens |
| `uploads_swap_test.sh` / `restore_flow_test.sh` / `backup_test.sh` | 79 / 45 / 41 checks pass, 0 fail (were 33 / 23 / 32); fake Docker and disposable directories |
| `check-ci-graph.mjs --self-test` | graph OK; all 5 deliberately broken graphs rejected |
| Real-browser check (built-in browser, dashboard on `http://localhost:5173` against the `local` backend on H2) | R4-03 reproduced the old way and passes: see R4-03 |
| V34 rehearsal on disposable data (H2, PostgreSQL mode) | passes: backfill, provenance, idempotence, rollback compatibility |

Not run (and why): real PostgreSQL / Redis / concurrency suites, `promtool test rules`, container restore (`deploy/restore_test.sh`), CI, native-device,
provider, cloud/offsite and load checks. See the last section; every one of them stays an open launch gate.

---

## R4-01 — Restore rollback correctness: **fixed**

- **Root cause.** The rollback of a failed uploads swap used plain `mv` calls assumed infallible, deleted its journal regardless, and `restore.sh` read
  any failed swap as "old uploads are back": it restored the database from the safety copy and restarted the backend over a mixed uploads tree.
- **Change.** `uploads_swap.sh` now keeps a recovery journal (`L:` original names, `S:` staged names, `DONE`) that is removed only after the rollback
  has **verified** that the retained directory is empty, every original name is live, and no staged-only name is live. Every recovery rename is checked, never nests
  into an existing destination, and the rollback is resumable (run it again after fixing the cause). Exit codes: `1` = failed and the files are provably as before;
  `3` = RECOVERY FAILED (mixed state, nothing deleted). A swap refuses to start while a journal exists. `restore.sh` starts the backend only when the database and
  the uploads are known consistent; on exit code 3 (or anything unexpected) it does not touch the database, stays stopped and prints the journal, the previous
  directory and the exact commands; an exit trap says **STOPPED** whenever it ends with the backend stopped.
- **Files.** `deploy/backup/uploads_swap.sh`, `deploy/restore.sh`, `deploy/backup/uploads_swap_test.sh`, `deploy/restore_flow_test.sh`, `docs/runbooks.md`.
- **Tests.** `uploads_swap_test.sh`: forward failure at 1–4 renames × rollback failure at 0–2, a real `mv` wrapper failing both directions (the audit reproduction, now asserting
  exit 3 and retained files, then recovery once the rename works), an explicit rollback failing halfway and resuming, rollback of a swap from before the journal existed,
  refusal of a new swap while recovery is pending. `restore_flow_test.sh` cases G (real rename errors both ways: backend not started, no second database restore,
  journal retained, manual rollback completes) and O (hook failure of the way back). All pass (79 checks).
- **Compatibility.** Journal files are new `.restore-journal-<id>` names inside the uploads volume (`.restore-*` names are already ignored by the application files).
  The old rollback of a swap that left no journal still works. Exit code 3 is new; nothing else parses it.
- **Remaining.** Rehearse on a real Docker volume (gate 36).

## R4-02 — SOS destination integrity: **fixed**

- **Root cause.** `SafetyService.toAdminDto` read the live `SavedAddress` instead of the booking's destination snapshot (B-05).
- **Change.** The SOS/admin projection uses `BookingPrivacy.destinationOf(booking)` (the same projection as the booking DTOs): the agreed address, with the legacy
  fallback to the saved address only for a row with no snapshot. New fields keep the reported GPS fix distinct from the agreed destination: `destinationLatitude`,
  `destinationLongitude`, `destinationBackfilled` (true when V34 copied the text because the original was never recorded, so support knows the destination may be
  reconstructed). The SOS text messages carry only the reported GPS link, so no other downstream consumer used the address.
- **Files.** `SafetyService.java`, `ApiResponse.java`, `api-contract/schemas.txt` (additive), `BookingDestinationSnapshotApiTest.java`.
- **Tests (pass).** Saved-address edit after booking; an explicit amendment followed by another edit and the admin resolve response; a V34-backfilled booking (flag shown);
  a legacy row with no snapshot (falls back to the saved address). Reported GPS asserted separately.
- **Compatibility.** Additive DTO fields; the dashboard ignores unknown fields. The dashboard does not yet display the new fields (the address text is already correct).

## R4-03 — Cross-tab account isolation: **fixed**

- **Root cause.** A storage event only re-ran profile hydration; mounted pages (and their loaded rows) survived, route rendering had no capability guard.
- **Change** (`App.jsx`). A session-hint change from another tab: bump an `epoch`, close dialogs/menus, route to the dashboard, set the unprivileged loading session and hydrate
  the new identity. The whole authenticated tree (sidebar, main panel, confirm host) is keyed by the epoch, so every screen and its loaded rows, details and drafts
  are dropped at once. Routes render only when `navAllowed(route)` (the same matrix as the navigation) and, while the profile is unknown, only the dashboard; the sidebar offers only
  unrestricted screens until the profile arrives. A failed hydration leaves the unprivileged tab with the existing retry banner (never the old identity); a 401 returns to sign-in.
- **Tests.** `App.crosstab.test.jsx` (6): Super admin with a loaded SOS row → Finance (slow profile: the row is gone before the profile arrives and stays gone; restricted screen not requested again;
  failed hydration; 401; other tab signs out; same account signing in elsewhere). `App.session.test.jsx` updated (no protected screen before the profile).
- **Real browser.** Super admin with the demo SOS row loaded in `Safety (SOS)`; the other tab's Finance sign-in was reproduced by logging in as Finance against the same cookie jar and
  delivering the `storage` event: result — SOS text absent, identity "Finance B", navigation reduced to Dashboard / Users & providers / Bookings / Settlements / Policies, route Dashboard.
  (The built-in browser's tabs do not share `localStorage`, so the event was dispatched rather than produced by a second tab. The page must be served from the same site as the API for the
  `SameSite=Strict` refresh cookie, hence `localhost` on both.)
- **Compatibility.** While loading, the sidebar now shows only Dashboard / Policies (previously every item). A user who clicked a screen during loading must click again after the profile arrives.
- **Remaining.** Gate 29 (native browsers, real two-tab ordering, screen readers).

## R4-04 — Private body isolation: **fixed**

- **Root cause.** `authedBlobFetch` checked the generation after headers; callers then awaited the body and created the URL / download.
- **Change** (`api.js`). New `authedBlob()` validates the session generation after the **complete** body and before any URL or download is created; one helper for documents and every CSV export.
  A session change (`setTokens`, `clearTokens`, the cross-tab storage listener) also aborts in-flight private transfers (`AbortController`); an aborted or late transfer rejects with
  `SESSION_CHANGED`. JSON requests already validated after their body.
- **Tests.** `api.blob-session.test.js` (7): body finishing after account change, after logout, after a storage-event sign-in elsewhere, export triggering no download, transfer cancelled, normal paths still work, HTTP error path.
- **Compatibility.** None (internal).

## R4-05 — Mobile authentication races: **fixed**

- **Root cause.** The session generation changes only when tokens are stored/cleared, which is too late to protect an operation still waiting for the server; the remember-me=false cold-start branch
  wiped storage with no guard, login's failure branch and the generic catch emitted unconditionally, and `SessionChangedException` (a `NetworkException`) was converted to an ordinary failure.
- **Change.** `SecureStorage` gains an **auth attempt counter** (`beginAuthAttempt`, `isCurrentAttempt`) and a credential lock. Sign-in, registration and sign-out begin an attempt; the repository stores
  tokens only for the current attempt, under the lock (so two operations cannot interleave their writes), revokes the session it just opened on the server if it was overtaken, and returns
  `SessionChangedFailure` for obsolete outcomes; `clearAll` queues behind running writes. `AuthBloc` checks attempt and generation after every await before any emit, storage change or revocation: login, registration, OTP,
  cold-start check (including reading the stored tokens for revocation), logout (an overtaken sign-out does not wipe the new credentials but still revokes the session it was asked to end) and the
  generic catch (an obsolete operation's exception publishes nothing). `SessionChangedException` is caught first everywhere in the auth repository, so its meaning is preserved.
- **Files.** `secure_storage.dart`, `auth_repository_impl.dart`, `auth_bloc.dart`, `injection_container.dart`.
- **Tests.** `auth_attempt_race_test.dart` (12) including both audit reproductions inverted, an obsolete success (nothing stored, orphan revoked), obsolete ordinary failure, unexpected exception, current-login failures still shown,
  cold start vs login, sign-out vs sign-in, OTP after sign-in, obsolete registration, lock ordering. The existing M-01/M-04 suites pass unchanged.
- **Compatibility.** `AuthRepositoryImpl` has an optional `revokeTokens` hook; callers that do not pass it behave as before.
- **Remaining.** Gate 30 (device, slow network).

## R4-06 — Safety backup encryption and retention: **fixed**

- **Root cause.** `restore.sh` wrote `backups/pre-restore-*.dump` in plaintext at the backups root, outside the retention find and outside the cleanup trap.
- **Change.** The safety copy follows the backup policy: taken after the backend is stopped, verified (`pg_restore --list` and a scratch-database restore), **encrypted with the backup key** (same cipher; decrypt-and-compare verified),
  mode 600, in `backups/safety/pre-restore-<id>.dump.enc` (a plaintext copy only with `BACKUP_ALLOW_UNENCRYPTED=1`; without a key and without that waiver the restore refuses before touching anything).
  Disk capacity is checked first against `pg_database_size` (temp dir and `backups/safety`, doubled when they share a filesystem). Partial files are removed by the exit trap. The backup job prunes
  safety copies after `BACKUP_SAFETY_KEEP_DAYS` (default 14), keeps a copy while `.restore-previous-<id>` still exists (the pair is not purged) and removes stale `*.partial`. Rollback reuses the verified plaintext
  inside the private temp dir; the encrypted file is kept until the operator purges it. The off-site job never ships `safety/`.
- **Files.** `deploy/restore.sh`, `deploy/backup/backup.sh`, `deploy/docker-compose.prod.yml`, `deploy/.env.example`, `docs/runbooks.md`, `deploy/restore_flow_test.sh`, `deploy/backup/backup_test.sh`.
- **Tests.** `restore_flow_test.sh` H/H2 (encrypted, no plaintext, decrypts back, scratch-verified, rollback from it; mode 600 where the filesystem honours it), I (refusal without key), J (disk), F (no leftovers);
  `backup_test.sh` safety retention cases (old deleted, pair-pending kept with a warning, recent kept, stale partial removed).
- **Compatibility.** New directory `backups/safety`; older plaintext `pre-restore-*.dump` files already on a server are not touched or migrated: delete them by hand after checking (they were never retained by the job).
  New optional variable `BACKUP_SAFETY_KEEP_DAYS`. The mounted `uploads_references.sql` is new in the backup container.
- **Remaining.** Gate 36 on a real server; `BACKUP_KEY_FILE` escrow (gate 4).

## R4-07 — SOS ordering and freshness: **fixed**

- **Root cause.** `useLoad` (initial/manual) and the poll were separate streams; the "live" confirmation fired on every data change, including local ones.
- **Change** (`SafetyQueue`). One ordered stream: every read (first load, retry, global refresh, badge trigger, 15 s poll) gets a sequence number when it starts; an answer is accepted only if no newer read
  was already accepted, it was not abandoned by its 10 s timeout (now applied to the first/manual loads too) and no local change happened after it started. Freshness (`Live · updated`) is recorded
  only by an accepted server read. Closing an alert is a local change: it removes the row, records no freshness, ignores reads that started before it and immediately starts a confirming read.
  A manual retry with rows already shown no longer replaces them by a skeleton.
- **Tests.** `Safety.ordering.test.jsx` (6) incl. the audit reproduction (initial read finishing after a newer poll), a timed-out initial read recovered by the next poll, reversed badge/initial answers,
  closing an alert with an older read in flight and the timestamp unchanged, initial failure then recovery, a hanging retry. The 8 AD-05 tests pass.
- **Remaining.** Gate 15 (delivered on-call alerts).

## R4-08 — Release checks: **fixed**

- **Root cause.** `deploy-staging` needed only `backend` and `admin`.
- **Change** (`.github/workflows/ci.yml`). New `release-gate` job (`always()`, push to main) needs `ci-graph`, backend, admin, monitoring-rules, backup-restore, sbom, flutter, android and dependency-scan and passes only if every
  `needs.<job>.result` is `success`; `deploy-staging` now needs only `release-gate`. `dependency-scan` exposes an output `scan` = `ran` | `skipped`, writes a step summary line and a warning, and the gate
  prints it; the repository variable `REQUIRE_CVE_SCAN=true` turns a skipped scan into a gate failure (set it for production promotion). New `ci-graph` job runs `.github/scripts/check-ci-graph.mjs --self-test`
  which parses the workflow, requires `deploy-staging` to reach every required job transitively, `release-gate` to use `always()`, no `continue-on-error` on required jobs, and the scan output to exist; the self-test
  proves it rejects five broken graphs.
- **Verification.** The graph script passes locally and rejects all five mutations. The workflow itself has **not run** (no CI here); branch and environment protection are repository settings (gate 35).

## FU-1 — Mobile destination amendment: **fixed**

New "Change visit address" button on the booking screen (home visits in PENDING/ACCEPTED), a sheet listing the other saved addresses that says up front that an accepted visit returns to Pending, the existing
`PATCH /bookings/{id}/destination` through `ApiConstants.bookingDestination`, datasource, repository and `LiveBookingCubit.amendDestination`; backend refusals (radius, cutoff, ownership) appear inline. EN/AR strings added and
`flutter gen-l10n` regenerated. Files: `tracking_page.dart`, `address_amend_sheet.dart`, `live_booking_cubit.dart`, `booking_repository*.dart`, `booking_remote_datasource.dart`, `api_constants.dart`, `app_*.arb`.
Tests: `destination_amendment_test.dart` (6). The backend rules were already tested (`BookingDestinationSnapshotApiTest`). Needs the backend with the amendment endpoint (already in this release).

## FU-2 — Durable provider onboarding: **fixed** (device evidence open)

After the account exists, the provider setup (business details, staff, radius, ID photo paths, terms version) is written to secure storage as a `ProviderSetupCheckpoint` after each finished step and removed on success,
sign-out (`clearAll`) or a different account. **It never contains a password, OTP, phone, e-mail or token** (asserted by key list and text test). The pending screen offers "Finish setup where I left off" for NO_PROFILE /
NEEDS_DOCUMENTS; it runs the remaining steps (each safe to repeat; the profile step asks the server what it has), checks the photos still exist (otherwise says so and the existing document flow applies). The sign-up page and the
resume share one runner. Tests: `provider_setup_resume_test.dart` (6): kill after profile creation with a failing staff step, restore in a "new process", no duplicate profile/staff; photos gone; customer path; corrupt value; widget resume.
Compatibility: new secure-storage key `provider_setup_checkpoint`. Remaining: gate 30 (real kill and relaunch).

## FU-3 — Backup strategy and reconciliation: **mitigated**

- Reconciliation can no longer pass silently: the reference list ends with a `done|ok` row; a failed `psql`, a cut-off list or a missing terminator prints `RECONCILIATION NOT PERFORMED` and `reconcile_uploads.sh` exits 2 (never "0 missing").
  `restore.sh` reports `reconciliation: completed | FAILED(...)`.
- At backup time the references are read right after the dump and compared with the file list of the tarball just written; the result is in the manifest (`reconcile`, `missing_references`), the log and metrics
  `aiwa_backup_reconcile_ok` / `aiwa_backup_missing_references`; new alert `BackupReconcileFailed` (rule and promtool unit test **authored, not executed**).
- Strategy documented in the runbook (dump first, then files; safety copy; what a restore can and cannot guarantee). **Still two snapshots**: a file deleted between them is reported, not prevented. A stricter option
  (quiesce or filesystem snapshot) is described in the runbook, not built.
- Tests: `backup_test.sh` (missing, failed query, no terminator, success), `restore_flow_test.sh` M/N.

## FU-4 — Server-driven admin queues: **mitigated**

`GET /admin/complaints`, `/admin/flags` and `/admin/reviews` now take `query` (and `maxRating` for reviews) and return the real `totalElements`/`totalPages`; the dashboard screens use a `usePagedQuery` hook
(page 1 on filter/search change, 300 ms debounce, ordered answers, refresh-button aware) instead of collecting up to 50 pages. A typed `%` or `_` is not a wildcard (`Searches.pattern`); sorting is now explicit (newest first;
the old complaint list was unsorted). Search is a phrase match, not the old per-token AND.
**Found and fixed on the way:** a query-count test showed ~2 extra SQL statements per row (the inverse `User.providerProfile` one-to-one); the entity graphs now fetch it, and `User.adminPermissions` is batched.
Tests: `AdminQueueSearchApiTest` (5), `AdminQueueQueryCountTest` (statements for 20 rows vs 3 rows differ by at most 2), `Queues.paged.test.jsx` (10). Real browser: the Complaints screen sent `/admin/complaints?page=0&size=10`, footer "1–4 of 4",
a search sent `query=zzz-nothing` and rendered "No complaints".
**Remaining (why mitigated):** Verifications, Photo moderation, Chat reports, reported-review queue, Settlements and the SOS queue are still loaded lists with the cap notice (they are case queues or financial tables whose
rows leave or aggregate; each needs its own backend search). The Reviews CSV export now exports the shown page and says so.

## FU-5 — Newer-policy reload UX: **fixed**

`TermsPage` now drops the old policy text and the agreement as soon as a reload after "terms changed" starts, so a failed reload shows the load error with Retry (no outdated text, no useless Continue); the new text is announced
("The terms were updated while you were signing up…", EN/AR). Test: `terms_reload_failure_test.dart`.

## FU-6 — Integration contract, maintainability, performance: **mitigated**

- Integration: optional `SMS_RECEIPT_FIELD` / `EMAIL_RECEIPT_FIELD` (dotted JSON path). With it set, a 2xx without the provider's receipt is treated as not accepted; unset keeps the lenient behaviour. Tests: `GatewayReceiptContractTest` (4).
  The real receipt path per provider needs the sandbox (gate 39).
- Performance evidence: the N+1 above; statement-count test. Not measured: latency, PostgreSQL plans, load (gate 19).
- Migration: `V34MigrationRehearsalTest` rehearses V34 on H2 (PostgreSQL mode) with representative rows (edited saved address, archived address, venue visit, home visit without an address): 3 of 5 backfilled and flagged,
  provenance flag, no amendment timestamp, idempotent, an amended snapshot is never overwritten, the previous release can still insert. **This is not the production-copy rehearsal in real PostgreSQL (gate 27, blocked).**
- Deferred on purpose (priority P3, no incident evidence): splitting `BookingServiceImpl` (2,089 lines) and `App.jsx` (now ~5,400 lines), typed per-provider gateway clients, dashboard bundle splitting, an HA/storage plan.

---

## Recheck of the 38 earlier findings and the potential risks

All 29 previously **Fixed** rows were re-examined in the code touched here; their suites pass unchanged (the three tests updated for R4-03/FU-4 changed only for the new loading/paging behaviour).

| Previous | Was | Now | Note |
| --- | --- | --- | --- |
| B-05 | Partial | Fixed | SOS projection (R4-02), mobile amendment (FU-1); V34 on real data is gate 27 |
| M-01 | Partial | Fixed | R4-05 |
| M-05 | Mitigated | Fixed | checkpoint (FU-2); device evidence open |
| M-07 | Fixed (UX follow-up) | Fixed | FU-5 |
| AD-04 | Partial | Fixed | R4-03/04 |
| AD-05 | Partial | Fixed | R4-07 |
| AD-13 | Mitigated | Mitigated | FU-4, three of nine queues server-paged |
| I-02 | Partial | Fixed | R4-01 |
| I-03 | Mitigated | Mitigated | FU-3 |
| I-05 | External | **Blocked** | needs the bucket, IAM, lifecycle and key escrow evidence (gates 2–5, 28) |
| P-03 | browser gate | open | gate 29 |
| P-04 | incomplete | Fixed | R4-03/04 |
| P-07 | Fixed (lenient) | Mitigated | receipt contract (FU-6), provider sandbox open |
| all other | Fixed | Fixed | unchanged |

## Blocked by the environment (exact inputs)

1. **Real PostgreSQL / Redis**: Docker Desktop's Linux engine does not start non-interactively here (WSL distro `docker-desktop` stopped; no local PostgreSQL). Needed: a running Docker engine or a PostgreSQL 16 instance + Redis, then
   `mvn verify` against it, Flyway V1→V34 on a **copy of production data** (read `destination_backfilled`), concurrency suites (gates 1, 27).
2. **promtool and container restore**: `docker run prom/prometheus promtool test rules alerts_test.yml` (includes the new `BackupReconcileFailed` test), `deploy/restore_test.sh`, a real restore with a full-disk and failed-rename drill (gates 24, 26, 36).
3. **CI**: push, confirm every job including `ci-graph`/`release-gate`, set `NVD_API_KEY`, `REQUIRE_CVE_SCAN`, branch/environment protection (gates 1, 20, 35).
4. **Devices / native browsers / providers / cloud / offsite / load**: gates 2–5, 15, 17, 18, 19, 21, 28–30, 37–40.
5. **Production deployment, live restores, external messages, cloud mutations**: not authorized, not performed.

## Production-readiness decision

**Not ready for production.** All eight round 4 findings and the repository-actionable follow-ups are fixed or mitigated and tested locally, but every launch gate that needs a real environment is still open (now 40 rows), and the items above could not be executed here.
Recommended next step: staging deployment with real PostgreSQL, the V34 production-copy rehearsal, the restore/rollback drills (gate 36), the two-tab browser check (gate 37) and the device pass (gate 38).
