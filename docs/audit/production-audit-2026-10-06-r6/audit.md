# AIWA remediation verification — round 6

Date: 2026-10-06. Project: D:/AIWA PROJECT/AIWA. Branch: main. Audited application commit: `b2d70b93399ac318d4aa7ce83533f9d6bf485827`.

## 1. Decision and scope

**Not ready for production.** The four round 5 defect scenarios are addressed in the available source/tests, and the six remaining admin queues now use server paging/search. However, three additional reproducible cases remain: **1 High and 2 Medium**. Recovery and mobile-session closure claims need qualification, and the oldest-SOS banner disappears for a zero-match search.

This pass reviewed the six remediation commits after ddebaf9, reran the available suites, clean-installed dashboard dependencies from the local cache, performed a fresh approved public npm advisory check, and added three isolated code reproductions. It is verification of the updated paths and their regressions, not fresh production execution of every API or independent certification of every historical finding.

The application working tree was clean before and throughout validation. The remediation is **committed**, contrary to the current handoff/record saying it is uncommitted. No application source, project tests, dependencies, migrations, deployment settings, npm registry configuration or runtime data were changed by this audit. Delivery adds this audit folder and updates HANDOFF.md; existing reports remain history.

## 2. Fresh validation

| Check | Fresh result | Boundary |
| --- | --- | --- |
| Backend, JDK 17, offline Maven | **506 tests**, 0 failures/errors/skips | H2/test doubles; not PostgreSQL/Redis. [Log](validation/backend-tests.txt) |
| Clean locked dashboard installation | **Pass**, 151 packages installed from local npm cache | Offline, ignore-scripts; no package/lock/registry modification. [Log](validation/admin-install.txt) |
| Dashboard | **221 tests / 33 files**, all pass | Vitest/jsdom, not native browser. [Log](validation/admin-tests.txt) |
| Dashboard build | Pass; JS 347.97 kB / gzip 101.34 kB | Build output, not runtime performance. [Log](validation/admin-build.txt) |
| Public npm production advisory gate | **0 reported vulnerabilities**, exit 0 | Approved dependency-only check; current registry evidence, not proof of absence of vulnerabilities. [JSON](validation/admin-advisories-public.json) |
| Resolved build dependency | source-map-js **1.2.2** via Vite/PostCSS | [Tree](validation/dependency-tree.txt) |
| Flutter analyzer / tests | **No issues / 253 tests pass** | Host tests/goldens, no device/release evidence. [Analysis](validation/flutter-analyze.txt), [tests](validation/flutter-tests.txt) |
| Backup / swap / restore-flow suites | **47 / 83 / 67** assertions pass | Fake DB/Docker, disposable files; NTFS permission checks skipped. [Log](validation/shell-checks.txt) |
| CI graph | Pass; **5** broken graph mutations rejected | Static local check, not GitHub Actions execution. [Log](validation/ci-graph.txt) |
| Three audit reproductions | All confirm the described defects | Retry harness: 69 assertions including 2 added assertions; Flutter: 1; dashboard API: 1. [Evidence guide](validation/README.md) |

All **691 tracked snapshot inputs** match the live project byte-for-byte: [manifest](source-manifest.tsv), [baseline](validation/baseline.txt). Audit-only Dart/JS probes were run separately and removed from the snapshot's normal test locations before baseline suites. A passing defect probe asserts faulty behavior, not a repaired implementation.

## 3. R6-01 — A safety-copy failure during recovery retry restarts an inconsistent pair

**Severity: High. Category: recovery correctness / data integrity. Status: confirmed with the actual restore/rollback scripts inside the existing fake-Docker harness.** This limits the broader I-02/R5-03 closure claim; the new normal paired-undo ordering is improved.

Source: [restore.sh:188](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:188>) through its `abort_with_backend` restart at [line 191](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:191>). The helper is used when the current safety dump cannot be produced, verified, encrypted or saved, including `--undo`.

The helper assumes that nothing changed **during this invocation** means it is safe to start the backend. A retry can begin after a previous undo already restored the old database but failed to restore the old uploads. That entry state is intentionally stopped and inconsistent. Failing to save a new safety copy does not repair it, yet the helper starts the backend anyway.

Reproduction:

1. Successfully restore a new database/upload pair in the disposable harness; retain the previous pair.
2. Run `--undo <id>` with file rollback fault injection. The previous database is restored, files remain the new ones, and the backend is correctly left stopped.
3. Retry `--undo <id>` with a failing safety `pg_dump`. The retry performs no database or file rollback but logs `start backend`, while only the new avatar remains live and the database is still the previous one.

[Fixture](validation/r6_retry_audit.sh), [log](validation/retry-probe.txt). The model records database transitions and file content; it does not demonstrate actual production traffic or file loss.

Required change: an unsuccessful undo/recovery must preserve the stopped state until the pair is verified. Do not unconditionally restart from the safety-copy abort helper for an undo. Account for an already incomplete prior run; persist/check recovery phase where needed. Review the database-half failure guidance too: its unconditional assertion that the existing pair is intact and suggestion to start the backend are not valid for every recovery retry.

Acceptance: fail the file half, then retry with safety dump, verification, encryption and save failures. Every unsuccessful retry must remain stopped with both generations and recovery artifacts retained. Also cover a failed database half when entering from a previously incomplete recovery; never print unconditional safe-start guidance for an unknown pair. Keep the existing successful paired undo and automatic rollback regressions.

## 4. R6-02 — An old account's 423 response logs out the newer account

**Severity: Medium. Category: session ownership / availability. Status: confirmed in a host test using the real ApiClient, AuthRepositoryImpl, SecureStorage and AuthBloc.** No out-of-order native storage write is needed. R5-01's token-write fix is present, but the broader M-01 session boundary remains partial.

Source: [ApiClient._ErrorInterceptor:353](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/core/network/api_client.dart:353>) and [_ThemedAppState._onAuthEvent:124](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/app.dart:124>).

Successful responses and the refresh/401 path check request generation. The error mapper's global routing for 423 and role-forbidden 403 does not. It emits a bare status integer; the app consumes 423 as an unconditional logout of whichever account is current and navigation to Account locked.

Reproduction:

1. Send a delayed protected request with account A's access token.
2. Sign in as B through the real AuthBloc/repository and assert B is authenticated with B's stored access/id.
3. Return HTTP 423 for the old A request.
4. The client emits 423; a listener mirroring the app's current 423 handler dispatches AuthLogoutEvent. The real bloc becomes unauthenticated and clears B's access and refresh tokens.

[Fixture](validation/r6_stale_lock_audit_test.dart), [log](validation/stale-lock-probe.txt). The test does not mount the native app/router or contact the backend. Logout/storage behavior is exercised; the additional locked-page navigation is established from _ThemedAppState source. The same unowned branch emits role-forbidden 403 events, which can route a newer session to Forbidden; that adjacent effect is source-reviewed, not a second device reproduction.

Required change: apply session ownership to failed responses/global events as well as successful responses. Reject or suppress obsolete errors before global routing, and carry/check session or attempt ownership at event consumption so an event queued before an account change cannot act on the later account. Preserve routing for genuinely current-session lock/permission failures.

Acceptance: delayed A 423/role-forbidden 403 after B sign-in must leave B authenticated with its credentials intact and no inappropriate navigation. Cover a queued auth event delivered after account change, a new sign-in in progress, and current-session failures that must still route correctly. Keep all seven refresh-write regressions.

## 5. R6-03 — Zero-match SOS search hides the global oldest open alert

**Severity: Medium. Category: safety queue visibility. Status: confirmed in an API-helper test; the banner removal follows directly from the render condition.** Server paging itself is implemented; this is a remaining edge case in its oldest-alert guarantee.

Source: [api.safetyPage:585](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src/api.js:585>) and [SafetyQueue banner:3878](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src/App.jsx:3878>).

The independent oldest-open request is inside `if (current.total > 0)`. During a search, `current.total` counts **matches**, not the whole open queue. A search with no matches skips the global request, returns `oldest: null`, and removes the banner even while an open alert exists. This contradicts the new helper/render contract and remediation record saying the search does not narrow the oldest-alert read.

Reproduction: the synthetic API contains open alert 99. An unfiltered call returns it as oldest. Search for an unrelated customer and return an empty matching page. The helper performs only that filtered request and returns no oldest alert; it never asks the unfiltered queue. [Fixture](validation/r6-safety-audit.test.js), [log](validation/safety-search-probe.txt).

The matching list correctly says No matches; this is not evidence that the backend lost the alert or that the list claims the entire open queue is empty. The defect is suppression of the explicitly global safety banner.

Required change: derive the oldest-open read from global queue knowledge, independently of filtered match count. With a search present, read the global oldest even when there are zero matches. Retain the one-call optimization when the unfiltered first page truly contains the whole queue, the accepted-read ordering and the existing second-read failure behavior.

Acceptance: an empty matching page must coexist with a banner for an unrelated oldest open alert; a truly empty global queue must show none; Resolved must not request/display an open banner. Test page/search changes, second-read failure and resolution of the global oldest.

## 6. Closure of the round 5 scenarios

| Item | Current assessment | Evidence / qualification |
| --- | --- | --- |
| R5-01 delayed refresh overwrites B credentials | **Original scenario fixed in local evidence** | Refresh pair writes and conditional clears now share the credential lock and recheck ownership inside it; seven added tests and full mobile suite pass. Broader session routing still has R6-02. iOS/device gate 41 remains open. |
| R5-02 backup query reads later live DB | **Fixed in reviewed source/stub evidence** | References are read with `psql -d <scratch>` from the restored dump before scratch deletion; the saved list is compared with the tar. Failed/incomplete states and cleanup have added tests. Real PostgreSQL/volume gate 42 remains open. |
| R5-03 database-first manual undo restarts between halves | **Original scenario fixed; recovery remains partial** | New `--undo` stops across both halves and starts once afterward; failure cases retain artifacts. R6-01 covers an unsuccessful retry not exercised by those tests. Real-container gate 43 remains open. |
| R5-04 source-map-js 1.2.1 | **Locally fixed** | Lockfile and clean install resolve 1.2.2; fresh production advisory gate exits 0; tests/build pass; CI policy unchanged. Actual CI gate 45 remains open. |
| AD-13 six remaining queues | **Server paging/search implemented; oldest-SOS edge case remains** | Backend 8 added H2 tests, dashboard 28 new tests plus old suites; real totals, filters and bounded calls. R6-03 remains; PostgreSQL scale/plan/statement-count gate 44 is open. |

The changed controller queries retain their existing permission boundaries. Verification, Photo moderation, Chat reports, Reported reviews, Settlements and SOS now use server search/pages. Reported review/chat queries exclude orphan targets before paging/counting. The settlement query groups/counts providers with per-provider status predicates. These queries passed H2 tests; PostgreSQL syntax/dialect/plan behavior was not exercised.

The earlier requestAllPages SOS test was replaced by oldest-read tests, and the sign-out-inside-write test was adapted to avoid a nested-lock deadlock. The reviewed changes test the new behavior, but zero-match oldest search, delayed non-401 global errors, and failures after incomplete recovery are not covered by the normal suites. Do not equate green totals with closure of these missing cases.

## 7. Architecture and API compatibility

Core architecture remains Flutter/Bloc/Dio, Java 17 Spring MVC/Security/JPA/Flyway, React/Vite and the single-host production compose stack. No new REST handler was introduced: the [current static inventory](api-inventory.md) still contains **183 handlers / 29 controllers**, now with updated queue parameters and reachable operations.

Existing queue routes gain query/filter/order parameters; no ownership/capability relaxation was identified in their changed mappings. Search remains phrase matching with typed wildcard characters removed. The dashboard uses actual totals rather than collecting capped pages; settlement chips and page-only reported-review CSV are deliberate behavior changes in the remediation record. The new restore undo is a CLI change, not a REST route. [Updated flow notes](api-flows.md).

The earlier SOS booking destination projection, destination amendment UI, provider checkpoint and newer-policy reload fixes were not altered by these commits and their full suites still pass. Their real migration/device checks remain open. Per-row target lookups remain in reported-review/chat DTO mapping, and no fresh statement-count/load measurement was added for the six queues; record this as a performance-validation follow-up, not a demonstrated production outage.

## 8. External evidence and readiness

Fresh Docker inspection still cannot connect to dockerDesktopLinuxEngine: its named pipe is absent. No psql/promtool executable was found. [Environment evidence](validation/environment.txt). No Docker service was started or configured.

Real PostgreSQL/Redis integration and production-copy V34 rehearsal, container recovery and Linux modes, promtool, actual CI/protection, native browsers/devices/signed releases, provider delivery, cloud IAM/offsite/lifecycle/immutability/key escrow, alert delivery and load remain unverified. The launch-signoff file has **45 incomplete evidence rows**, including five new remediation gates. They are operational decisions/checks as well as tests; local checks do not complete them. I-03's two-snapshot consistency limit and I-05's external evidence remain open.

This audit did not deploy, perform a live restore, send external messages or mutate cloud resources. The public dependency-only scan used the authorization already provided by the user; package/registry configuration was left untouched.

## 9. Next work

1. Make recovery retries conservative: no restart or unconditional safe-start instruction while pair consistency is unknown (R6-01).
2. Extend mobile session ownership to global error routing and event delivery (R6-02).
3. Keep the oldest-open SOS read independent of search match count (R6-03).
4. Convert the three defect fixtures into regressions asserting correct outcomes, rerun relevant suites, then execute the staging/device/CI gates with actual prerequisites. Preserve the successful fixes and historical evidence.

See [closure reconciliation](remediation-status.md), [coverage and commands](coverage.md), and [validation instructions](validation/README.md).
