# Round 6 remediation record

Date: 2026-10-06. Starting point: application commit `b2d70b9`. All changes below are **uncommitted** in the working tree. The audit files in this folder (audit.md, remediation-status.md, coverage.md, validation/) are historical evidence and were not edited; the audit fixtures that assert the defects are kept untouched in `validation/`.

## Summary

| ID | Severity | Status | Where fixed |
| --- | --- | --- | --- |
| R6-01 | High | Fixed in scripts + fake-docker fault injection; real-container drill open (gate 46) | `deploy/restore.sh` |
| R6-02 | Medium | Fixed in client + host tests; native/device check open (gate 47) | Flutter `api_client.dart`, `secure_storage.dart`, `auth_event.dart`, `auth_bloc.dart`, `app.dart` |
| R6-03 | Medium | Fixed in helper + UI + tests; real-browser check open (gate 48) | dashboard `api.js`, `App.jsx` |
| Follow-up | Perf | Per-row target lookups in chat-report / reported-review queues removed and measured | `ChatController`, `ReviewController`, two repositories |

## R6-01 recovery retry restarts an inconsistent pair

**Root cause.** `abort_with_backend` assumed "this run changed nothing" means the pair (database, uploads) is consistent and started the backend. A retry that follows an incomplete earlier undo (old database restored, uploads still the restored ones, backend deliberately stopped) changes nothing either, but the pair is inconsistent. The same unconditional assumption sat in the database-half failure text ("the restored pair is intact", "start the backend") and in the failed-restore / rolled-back paths.

**Fix.** `restore.sh` keeps a recovery marker, `backups/safety/.recovery-incomplete`, written before every backend stop and removed only by `start_backend_consistent` (the one place that starts the backend after a proven-consistent state). A run that finds the marker sets `pair_known=0`:
- any safety-copy failure (dump, list verification, scratch-restore verification, encryption, store) calls `stay_stopped`: exit non-zero, backend stays stopped, artifacts kept, repeat command printed, no start command;
- a failed database half after an incomplete earlier recovery prints "not known to be a consistent pair" and no start instruction (from a consistent start the existing guidance is unchanged, with a note to remove the marker if the operator gives up);
- a failed fresh restore, or a swap rolled back by this run, stays stopped in that state;
- a database-only run restores, then leaves the backend stopped, because it cannot prove the uploads;
- a run that completes both halves (undo, or restore with uploads) starts the backend once and removes the marker.
Runs that begin from a consistent state behave as before (safety-copy failure restarts the backend and leaves no marker). Hand-recovery messages now say that `./restore.sh <safety dump>` leaves the backend stopped while the marker exists. `docs/runbooks.md` documents the marker and the updated failure table.

**Tests.** `deploy/restore_flow_test.sh` (67 → 93 assertions). The fake docker now tracks backend state and database generation and can fail the nth `--list`, the nth scratch restore, encryption (fake openssl) and the safety-copy rename (mv wrapper). New cases: incomplete undo setup; then, per fault (safety dump, list verification, scratch verification, encryption, store), a retry that asserts exit ≠ 0, no `start backend` call, backend state stopped, old database generation and restored files, journal/previous files/original `.enc` safety copy retained, marker present, no `.partial`, no database restore and no uploads rollback, "not known to belong together" and the repeat command; a failed database half on the retry (no "intact" claim, no start instruction); a plain fresh restore failing its safety copy; a database-only undo on an unknown pair; a clean retry (exit 0, old database and old files, backend started exactly once after database restore and rollback, marker gone); a consistent-start undo with a failing safety copy (restarts, no marker). **Verified red before the fix:** the same suite against the original script fails 15 assertions; green after.

## R6-02 stale account-lock / forbidden response affects the newer account

**Root cause.** Successful responses and the 401 path checked the session generation; the error mapper's global routing of 423 and role-403 did not. It published a bare status integer and `_ThemedAppState` logged out and redirected whichever account was current. Nothing checked ownership at consumption or in the asynchronous logout/redirect.

**Fix.**
- `SessionOwner(generation, attempt)` and `SecureStorage.currentOwner/owns` (the stored session plus the credential operation number that is current). Each request is tagged with both (`extra['session']`, `extra['attempt']`); a newer sign-in that is still waiting for the server bumps `attempt`, so it protects an in-progress sign-in too.
- `ApiClient.authEvents` carries `SessionEvent(status, owner)`. The error mapper drops 423 / role-403 from a request whose owner is no longer current (no event; the stale caller gets `SessionChangedException`). The refresh-rejected 401 event is tagged with the signed-out generation and the request's attempt.
- `routeSessionEvent` (top-level, used by `_ThemedAppState`) discards an event unless its owner is current when delivered, so an event queued before an account change is dropped. The sign-out it dispatches is `AuthLogoutEvent(owner:)`; `AuthBloc` re-checks the owner before beginning its own credential operation and again after reading tokens, and reports `applied`. The redirect to Account locked / Session expired happens only if the logout was applied.
- Unchanged: credential lock, refresh-generation checks and the seven R5 refresh-write regressions (still pass).

**Tests.** New `test/core/session_event_ownership_test.dart` (12 tests; real ApiClient, repository, storage, AuthBloc and event routing; fake adapter and secure-storage plugin): delayed A 423 and role-403 after B signs in; A 423 while B's sign-in is still waiting; queued 423 / 401 / 403 delivered after account change; queued logout dropped by the bloc; logout overtaken while reading tokens; current-session 423, role-403 and refresh-401 still sign out / navigate correctly; late 423 after plain sign-out; locked-account login still routes. Each asserts B's auth state, tokens, user id and navigation. Existing tests adapted only for the new event type. The audit's defect fixture already demonstrates the failure on the old code (new tests use the new API, so they cannot compile against it). Flutter: analyzer clean, 265 tests (253 + 12).

## R6-03 zero-match SOS search hides the global oldest alert

**Root cause.** The second (global, `order=oldest`) read in `api.safetyPage` sat inside `if (current.total > 0)`, and during a search `total` counts matches.

**Fix.** `safetyPage` skips the global read only when the answer is already known: an unfiltered empty queue (no banner) and an unfiltered first page that holds the whole queue (last row; one request). Otherwise (any search including zero matches, later pages, larger queues) it reads the global oldest. Resolved/All never read it. Both reads still belong to one call, so ordering and second-read failure behaviour are unchanged. Closing the alert shown in the banner clears it at once; the confirming read names the next oldest.

**Tests.** New `src/test/Safety.oldest.test.jsx` (15 tests) against a stateful fake of the SOS endpoint: helper cases (zero matches with a global alert, empty queue with/without search, one-request optimisation, later page, search that matches, Resolved/All, failed second read) and screen cases (zero-match banner plus "No matches", empty queue, Resolved, paging/search changes, obsolete answer dropped, failed second read shown as not live, closing the oldest, closing the last). **Verified red before the fix:** 6 of 15 fail on the original source. Dashboard: 236 tests / 34 files; production build passes.

## Follow-up: per-row target lookups in the chat-report and reported-review queues

Measured with Hibernate statistics (`AdminQueueQueryCountTest`, new test, H2): 3 rows vs 20 rows, every row with its own people.

| Queue | Before (3 / 20 rows) | After (3 / 20 rows) |
| --- | --- | --- |
| Chat reports | 12 / 64 statements | 5 / 6 |
| Reported reviews | 15 / 84 | 5 / 6 |

Fix: one `IN` query per page fetching the targets with their people (`findAllWithSenderByIdIn`, `findAllWithPeopleByIdIn`, including `providerProfile` to avoid the inverse one-to-one lookup). Orphaned cases are still skipped, order and totals unchanged. This is a statement count on H2, not a PostgreSQL plan or latency measurement.

## Verification run

| Check | Result |
| --- | --- |
| `deploy/restore_flow_test.sh` | 93 passed, 0 failed (NTFS mode check skipped) |
| `deploy/backup/backup_test.sh` / `uploads_swap_test.sh` | 47 / 83 passed |
| `deploy/restore_test.sh` | **not run**: needs Docker, engine absent |
| CI graph check (`--self-test`) | OK, 5 mutations rejected |
| Dashboard Vitest / build | 236 tests (34 files) / build OK |
| `npm audit --omit=dev --audit-level=high` | 0 vulnerabilities, exit 0 |
| Flutter analyze / test | no issues / 265 passed (`--concurrency=2`; the default parallelism stalled this machine, every file passes alone) |
| Backend (JDK 17, offline Maven) | 507 tests, 0 failures (506 + 1 new); run with `-DargLine="-Xmx640m -XX:MaxMetaspaceSize=320m -Xss512k"` because uncapped runs crashed the JVM on native memory on this machine |

## Remaining limitations (not closed by these changes)

- Gates 1–48 of `docs/launch-signoff.md` have no owner/decision/evidence; three new gates (46–48) track this round. Host tests do not close them.
- Real PostgreSQL/Redis, V34 rehearsal, query plans on staging-sized data, real-container recovery and Linux modes, native account switch on devices, real browsers, actual CI/release artifacts, provider delivery, monitoring, offsite/IAM/key escrow: unavailable here (no Docker engine, psql, promtool, devices, credentials). Procedures and expected evidence are in the gate rows and `docs/runbooks.md`.
- I-03 stays **mitigated, not resolved**: database dump and uploads archive are still two snapshots; reconciliation reports the difference after a restore.
- The recovery marker is conservative: after an incomplete recovery that the operator finishes by hand, the marker must be removed by hand once the pair is verified.
- A stale response that is not 423/role-403 still reaches its (already session-guarded) caller as before.
