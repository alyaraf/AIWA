# AIWA remediation verification — round 5

Date: 2026-10-06. Project: D:/AIWA PROJECT/AIWA. Branch: main. Audited commit: `ddebaf9e40d7fd1a071888a490aea23715e6d2bd`.

## 1. Decision and scope

**Do not launch yet.** The eight round 4 defect scenarios have been addressed in the reviewed source and their available regression suites pass. Four actionable findings remain: **1 High and 3 Medium**. Three have deterministic code reproductions; the fourth is an affected build dependency that fails the existing CI audit. Its upstream advisory is rated High, while the repository finding is Medium because no production request exploit path was established. Two code findings limit broader mobile-session/recovery closure claims; the third invalidates the new backup-time consistency signal.

This pass verifies the six remediation commits after `290a05f0606545c073c22e1753cc9ad5c584fa5a`, reviews the changed application/deployment paths and follow-ups, reruns the available suites, and adds targeted audit reproductions. It is not a fresh execution of every API against production dependencies. The [round 4 system audit](../production-audit-2026-10-05-r4/audit.md) remains the architectural and historical baseline; this report supersedes its remediation status where specified below.

The repository was clean before delivery. The fixes are **committed**, contrary to the previous handoff's claim of uncommitted remediation. No application source, production tests, dependencies, migrations or deployment configuration were changed by this audit. Tests/builds/probes ran in a disposable copy; delivery adds audit documentation and updates HANDOFF.md.

## 2. Fresh validation

| Check | Result | Evidence and limit |
| --- | --- | --- |
| Backend, JDK 17, offline Maven | **498 tests**, 0 failures/errors/skips | [Log](validation/backend-tests.txt); H2 and test doubles, not PostgreSQL/Redis |
| Dashboard, Node 20.20.2 | **193 tests / 32 files**, all pass | [Log](validation/admin-tests.txt); Vitest/jsdom, not native two-tab browser behavior |
| Dashboard production build | Pass; JS 349.53 kB / gzip 102.00 kB | [Log](validation/admin-build.txt); does not establish browser latency or deployed compatibility |
| Flutter analysis | No issues | [Log](validation/flutter-analyze.txt) |
| Flutter regression suite | **246 tests**, all pass | [Log](validation/flutter-tests.txt); host/widget/golden tests, not device or signed release evidence |
| Backup / uploads swap / outer restore harnesses | **41 / 79 / 45** assertions pass | [Log](validation/shell-checks.txt); stub database/Docker and disposable files; NTFS mode checks skipped |
| CI dependency graph and five negative mutations | Pass | [Log](validation/ci-graph.txt); static local graph check, not a GitHub Actions run |
| R5 refresh reproduction | Confirms mixed account credentials and subsequent A-authorized response | [Log](validation/refresh-probe.txt), [fixture](validation/r5_refresh_audit_test.dart) |
| R5 backup/undo reproductions | Confirm both defects | [Log](validation/backup-undo-probes.txt); extended restore harness passes 48 assertions, including 3 defect assertions |
| Fresh npm production advisory scan | **Fails: 1 High upstream advisory**, exit 1 | [JSON](validation/admin-advisories-public.json); source-map-js 1.2.1, build chain; R5-04 assesses actual repository scope. The user explicitly approved dependency-only registry egress. |

Audit probes assert the **presence of a defect**. Their passing result is reproduction evidence, not proof of remediation. The baseline suites exclude the audit-only Dart probe. Installed dependencies were reused from the earlier audit copy; no packages were installed or changed. All **687 tracked snapshot input files** match the current project byte-for-byte: [manifest](source-manifest.tsv), [baseline](validation/baseline.txt).

## 3. R5-01 — Delayed refresh writes account A's token over account B's session

**Severity: High. Category: session isolation / privacy. Status: confirmed by a deterministic Flutter test using the real ApiClient, SecureStorage and AuthRepositoryImpl.** This is a remaining defect in the broader M-01/R4-05 boundary, rather than a failure of the newly added stale-login tests.

Source: [ApiClient._refresh, line 294](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/core/network/api_client.dart:294>), [SecureStorage.withCredentialLock, line 35](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/core/storage/secure_storage.dart:35>), [AuthRepositoryImpl._storeSignIn, line 29](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/features/auth/data/repositories/auth_repository_impl.dart:29>).

The new credential lock serializes sign-in and deletion. Refresh still calls `saveAccessToken` and `saveRefreshToken` outside that lock. Checking the session generation before an asynchronous storage write does not prevent the write from finishing after another account has replaced the credentials.

Reproduction:

1. Account A has `A-old`, `A-refresh`, userId `1`. A protected request triggers refresh.
2. The synthetic refresh response contains `A-rotated`. Block its secure-storage access-token write **after** the generation check.
3. Account B signs in through the real repository and stores `B-access`, `B-refresh`, userId `2`; sign-in succeeds.
4. Release A's older storage write. Stored credentials are now `A-rotated`, **B-refresh**, userId **2**. The later generation check prevents only A's refresh-token write.
5. A new ApiClient request attaches `Bearer A-rotated`. The synthetic adapter distinguishes B's bearer token from A's and returns account A's payload.

The stale original request may be rejected correctly; that does not repair the credentials already overwritten. Subsequent requests belong to the current generation but carry A's token, potentially exposing A's private responses while the app identifies the user as B. No real accounts or production data were used.

Platform qualification: the fixture injects delayed out-of-order writes; it is not a device reproduction. The locked flutter_secure_storage 9.2.4 iOS implementation dispatches operations onto a concurrent global queue (cached SwiftFlutterSecureStoragePlugin.swift, line 32), so application code cannot rely on serialized native writes there. This concurrency implication is inferred from the inspected implementation. Android's implementation posts operations to one worker HandlerThread, so this fixture does **not** establish the same write ordering on Android. Native iOS verification remains required.

Required change: make every credential mutation, including successful refresh and refresh-failure clearing, participate in one serialized session-aware operation. Recheck ownership **inside** that operation before storing the complete token pair; prevent stale clears/events from affecting a newer session. Do not acquire the existing lock and then call a method that acquires it again.

Acceptance: a blocked A refresh followed by B sign-in must leave B's access/refresh/id intact, and the next request must authenticate as B. Cover delayed access and refresh writes, logout, refresh failure, and an account switch. Invert the defect assertions in the audit fixture when converting it into a regression test.

## 4. R5-02 — Backup reconciliation validates the live database, not the saved dump

**Severity: Medium. Category: recovery evidence / data integrity. Status: confirmed with real backup.sh and reconcile_uploads.sh plus synthetic database commands.** It narrows FU-3/I-03's claimed mitigation; two-snapshot consistency was already documented as incomplete.

Source: [backup.sh, line 76](<D:/AIWA PROJECT/AIWA/deploy/backup/backup.sh:76>) and [reconcile_pair call, line 152](<D:/AIWA PROJECT/AIWA/deploy/backup/backup.sh:152>).

The dump is taken first. The tarball is written later. `reconcile_pair` then executes an unqualified `psql` query using the live connection settings; it does not read references from the verified scratch restore or another snapshot representing the dump. The source comment and remediation record saying references are read immediately after the dump are also inaccurate: the query runs after tar creation.

Reproduction: the synthetic dump records `/files/public/a.jpg`; simulate deletion of the file and its live database reference after the dump; create the actual tarball without the file. The live query returns no references and `done|ok`. The backup succeeds and records `reconcile=ok`, `missing_references=0`, although the saved dump still requires the absent file. [Fixture](validation/r5_pair_audit.sh), [output](validation/backup-undo-probes.txt).

This is not a claim that the archive must prevent every concurrent deletion. It demonstrates that the new diagnostic can falsely describe the **backup pair** as clean, defeating detection of the exact inconsistency it was introduced to report. The post-restore query against a restored database is a separate path and its failed/incomplete-query handling is improved.

Required change: obtain references from the dump's actual restored snapshot (for example, while the verified scratch database is still available), then compare them with the archived file list. Preserve explicit failed/incomplete scan states. A production strategy that quiesces mutations or takes coordinated snapshots remains a separate consistency decision.

Acceptance: a file/reference deleted between the dump and tar must still be counted as missing for that dump. Test live reference additions/deletions, a failed scratch query, and an incomplete list. Rehearse on real PostgreSQL and an uploads volume before relying on this metric.

## 5. R5-03 — Printed whole-restore undo starts the backend between database and file rollback

**Severity: Medium. Category: recovery correctness / operator workflow. Status: confirmed by extending the existing fake-Docker outer restore harness.** The original automatic rollback failure is fixed; this residual operator path keeps the broader I-02 recovery claim partial.

Source: [restore.sh, line 230](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:230>) and [unconditional backend restart, line 206](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:206>).

After a successful paired restore, the script prints the undo order `restore.sh <safety-dump>` followed by `uploads_swap.sh rollback <restore-id>`. The first invocation restores only the database and unconditionally starts the backend. Until the second command completes, the old database is served with the new uploads. The file rollback itself then runs while the backend is active. The file helper also needs the backup container/volume invocation, not merely a bare host command.

Reproduction: perform a successful paired restore in the harness; run the printed database-first undo; verify the fake Docker log contains the old safety database restoration and `start backend` while the live volume still has only the new avatar. Only the subsequent file rollback restores the old avatar. [Fixture](validation/r5_undo_audit.sh), [output](validation/backup-undo-probes.txt). No live restore or application traffic was exercised.

Required change: provide one supported paired-undo workflow that stops the backend, restores/verifies both the safety database and previous uploads, and starts it only when both succeed. A failed half must keep it stopped with explicit recovery state and runnable commands. Update the printed guidance and runbook; a warning alone does not repair the ordering.

Acceptance: logs must show no backend start between the two restorations, and neither failure may restart it with mixed generations. Cover encrypted safety copies and retained recovery artifacts. Run the real-container drill after the isolated regression passes.

## 6. R5-04 — Affected build dependency fails the dashboard's CI advisory check

**Repository severity: Medium. Category: dependency / release readiness. Status: confirmed by the approved fresh npm scan and lockfile. Upstream advisory severity: High.** No dashboard-user exploit or running-service denial of service was demonstrated.

Source: [package-lock.json, line 2439](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/package-lock.json:2439>) and [mandatory CI scan, line 106](<D:/AIWA PROJECT/AIWA/.github/workflows/ci.yml:106>).

The lockfile and installed tree resolve Vite 6.4.3 → PostCSS 8.5.28 → source-map-js **1.2.1**. The fresh `npm audit --omit=dev --json --registry=https://registry.npmjs.org` reports GHSA-68fv-2mgg-jv7q / CVE-2026-93749 and exits 1. The advisory concerns denial of service when processing a malicious indexed source map; **1.2.2** is patched. [GitHub advisory](https://github.com/advisories/GHSA-68fv-2mgg-jv7q), [maintainer's 1.2.2 release](https://github.com/7rulnik/source-map-js/releases/tag/v1.2.2).

The production image serves built assets from nginx, and this dependency was found through the build tool chain; no application endpoint accepts source maps in the reviewed paths. Therefore upstream severity must not be described as a demonstrated High production-runtime vulnerability. However, the existing CI command uses `npm audit --omit=dev --audit-level=high`, so this lockfile is expected to fail that required check with the current registry data and prevent release-gate success. This CI implication is inferred from the source and local audit, not an actual GitHub Actions run.

Required change: refresh the affected transitive resolution to patched 1.2.2 or a compatible later release and commit the resulting lockfile; retain the High/critical audit gate. Reclassifying build-only tools may make installed-runtime inventory clearer, but merely moving Vite to devDependencies does not remove the vulnerable build input.

Acceptance: an updated dependency tree, clean-install tests/build, fresh High-threshold audit and an actual green CI run. No dependency was changed during this audit. [Scan JSON](validation/admin-advisories-public.json), [local tree](validation/dependency-tree.txt).

## 7. Verification of the eight round 4 findings

| ID | Original scenario | Current result and boundary |
| --- | --- | --- |
| R4-01 | OS rename fails during swap and rollback; backend restarts on mixed files | **Original scenario fixed.** Non-1 failure keeps backend stopped and recovery journal/files retained; 79 swap and 45 outer-flow checks pass. Full undo still has R5-03. |
| R4-02 | SOS projection follows an edited saved address | **Fixed in reviewed code.** SafetyService uses BookingPrivacy.destinationOf; edited/amended/legacy scenarios and V34 rehearsal pass. Real-data PostgreSQL rehearsal remains open. |
| R4-03 | Cross-tab Finance session retains another admin's restricted SOS rows | **Fixed in reviewed source/jsdom tests.** Storage-event epoch resets/remounts data, unverified session uses restricted navigation until /auth/me, and route permissions are enforced before restricted mounting. Native two-tab cookies/storage still need execution. |
| R4-04 | Private blob body finishes after account change | **Fixed in reviewed source/tests.** Abort tracking and a generation check after body completion reject obsolete blobs before URL/download creation. Native download behavior remains a browser gate. |
| R4-05 | Older startup/login/logout handlers clear or overwrite newer session state | **Original tested cases fixed; broader session isolation partial.** Attempt ownership and credential locking cover the added tests, but refresh bypasses the lock (R5-01). |
| R4-06 | Retained safety dump is plaintext and outside retention | **Fixed for newly created copies.** Required key/explicit waiver, verified encryption, backups/safety retention and retained-file-pair protection pass. Legacy plaintext copies on deployed hosts still require operator review/removal; Linux file modes not verified on NTFS. |
| R4-07 | Old initial/manual SOS read erases newer poll and claims freshness | **Fixed in reviewed source/tests.** All reads use shared ordering and timeout; filters remount; action completion rejects pre-action responses; freshness follows accepted reads. |
| R4-08 | Staging deploy waits only for backend/admin | **Fixed in workflow source.** release-gate requires every validation job and checks actual results; deploy-staging depends on it. Five graph mutations are rejected. CI/protection settings still unexecuted. |

Passing targeted cases does not justify closing unrelated flows or external gates. [Follow-up status](remediation-status.md) records the remaining qualifications.

## 8. Follow-ups and compatibility

Destination amendment is now exposed from mobile tracking through the existing backend endpoint. Its six tests and the backend snapshot/amendment tests pass. Provider post-registration setup now persists a checkpoint and resumes remaining steps; six tests cover interrupted setup and missing photos. Checkpoint account binding is present, and password/OTP/token/contact fields are excluded by the authored contract tests. Terms reload now clears old text/agreement and exposes Retry on failure; its new widget test passes. Actual device kill/relaunch and account switching remain open.

Complaints, Flags and Reviews now use server-side search/page totals; the backend search/query-count tests and ten dashboard paging tests pass. Verification, Photo moderation, Chat reports, Reported reviews, Settlements and SOS retain collected-list limits. **AD-13 remains mitigated, not complete.** Statement-count tests address the new ORM N+1 path, but do not measure PostgreSQL plans or production latency.

Optional SMS/EMAIL_RECEIPT_FIELD provides a configurable receipt check; four gateway tests pass. Real provider receipt shapes, delivery and typed provider-specific clients remain unverified/deferred. Deployment changes include BACKUP_SAFETY_KEEP_DAYS and mounting uploads_references.sql. The SOS DTO adds snapshot coordinates and provenance. Search semantics are now phrase matching. V34 remains compatible in the H2 rehearsal but needs a production-copy PostgreSQL exercise.

The [fresh static API inventory](api-inventory.md) still has **183 handler methods in 29 controllers**. Controller mappings and validation/authorization metadata are inventory evidence, not 183 successful runtime exercises. The principal changes are query/maxRating parameters on existing queue routes and the corrected SOS response projection; the mobile amendment uses an existing route. [Updated flow notes](api-flows.md).

## 9. External evidence and readiness

The Docker client is installed, but a fresh check could not connect to `dockerDesktopLinuxEngine`; its named pipe is absent. No local psql/promtool executable was found. Consequently, real PostgreSQL/Redis integration, production-data migration, container restore, Linux permission behavior and Prometheus rule execution remain unverified. Docker Desktop was not started or reconfigured.

CI execution, REQUIRE_CVE_SCAN/NVD key/protection configuration, genuine two-tab browsers, Android/iOS devices and signed releases, provider sandboxes, cloud IAM/lifecycle/immutability/key escrow, alert delivery and load require execution evidence. [Launch sign-off](../../launch-signoff.md) still contains **40 incomplete evidence rows**. They include operational sign-offs as well as tests; local green suites do not complete them. I-05 remains external/blocked by those missing inputs.

The earlier remediation's browser evidence used a simulated cross-tab storage event and is not sufficient to close native two-tab gate 37. This audit made no new native-browser claim. The fresh npm scan supersedes the earlier zero-advisory result; after automatic review initially blocked metadata egress, the user explicitly approved it and the check completed.

## 10. Required order of work

1. Fix R5-01 and add a regression that proves every final credential belongs to B after delayed A refresh.
2. Fix R5-02's dump-reference source and R5-03's coordinated undo; retain the existing rollback/encryption behavior and add the missing fault cases.
3. Resolve R5-04's affected transitive dependency and rerun the mandatory advisory gate, tests and build.
4. Execute staging PostgreSQL/V34, real recovery and promtool checks, CI gates, genuine browser/device/provider checks and the remaining sign-offs. Complete six remaining server-paged queues according to expected operating scale; resolve offsite evidence and the documented deployment decisions.

No production-ready claim is supported until these defects and required evidence are resolved. Commands, scope and reproduction instructions are in [coverage.md](coverage.md) and [validation/README.md](validation/README.md).
