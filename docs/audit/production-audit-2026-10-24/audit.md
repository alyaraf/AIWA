# AIWA post-change audit - 2026-10-24

Project: `D:/AIWA PROJECT/AIWA`.
Audited revision: `23f285f10e49d5aca97025f3322fa844a04af6a5` (`main`, matching the local `origin/main` ref). The application worktree was clean before the audit. Source was not fetched or changed. GitHub Actions metadata was read separately.

## Result

Four actionable findings remain: **1 High and 3 Medium**. No Critical vulnerability was established in the reviewed changes. The High finding concerns dependency maintenance and a currently failing release check, not a demonstrated attack on the deployed dashboard. Two Medium defects were reproduced with synthetic, isolated probes; the other is a workflow dependency gap confirmed from source.

The earlier security fixes are materially present. The old handoff's claims of uncommitted remediation and no CI evidence are superseded: the remediation is committed, and actual GitHub runs provide PostgreSQL, container, Android and scanner evidence. Production sign-off is still incomplete: today's npm release check fails, the backend CVE job has no successful scan evidence in the inspected runs, the findings below remain open, and the 54-row launch record is unsigned.

This is a post-change source review and test-based audit. It does not establish complete coverage of every endpoint or certify a deployed environment.

Scope: reviewed the changes after the committed October 6 security remediation (`8b34470`) through the audited HEAD, focusing on authentication/2FA, provider privacy and visibility, suspension/deletion, terms notifications and mobile routing/theme changes, exports, deployment/recovery and CI scanning. The prior security findings were reconciled against current source and regressions. A selected 19-file source hash manifest accompanies the evidence.

## Findings

| ID | Priority | Severity | Finding | Evidence |
| --- | --- | --- | --- | --- |
| A24-01 | P1 | High | Locked dashboard tooling has new advisories; the mandatory npm audit now fails | Fresh public npm audit, locked versions, upstream advisories |
| A24-02 | P2 | Medium | An old 2FA confirmation can complete a replacement enrollment | Real auth service and H2 repository, deterministic interleaving |
| A24-03 | P2 | Medium | Retrying a failed deployment makes automatic rollback select the failed release again | Actual deploy script with fake Git/Docker |
| A24-04 | P2 | Medium | Staging deployment does not depend on CodeQL or Trivy results | Workflow graph/source; actual deploy not triggered |

### A24-01: Update the locked tooling so the mandatory audit passes

Sources: [Vite resolution](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/package-lock.json:2611>), [Undici resolution](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/package-lock.json:2571>), [Vitest mocker resolution](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/package-lock.json:1528>), [CI audit](<D:/AIWA PROJECT/AIWA/.github/workflows/ci.yml:106>).

The fresh full npm audit reports **4 affected packages: 2 High, 2 Moderate**. The lockfile resolves Vite 6.4.3, Undici 7.30.0, and Vitest / @vitest/mocker 4.1.11. The exact CI command, `npm audit --omit=dev --audit-level=high`, exits **1** with **one High affected package, Vite**, because this project declares Vite under `dependencies`.

Upstream evidence, checked on 2026-10-24:

- Vite 6.4.3 is in the affected range for the Windows launch-editor command-injection chain; the advisory lists 6.4.4 as the patched 6.x release. Exploitation depends on a reachable development/editor path and relevant Windows/editor conditions. [Maintainer advisory](https://github.com/vitejs/launch-editor/security/advisories/GHSA-587h-7wmj-h5pm).
- Undici 7.30.0 is in the range for a High malicious-response denial of service; 7.30.1 patches it. This lockfile entry is dev-only through the test environment. [Maintainer advisory](https://github.com/nodejs/undici/security/advisories/GHSA-xjj6-f33q-929c).
- @vitest/mocker 4.1.11 is affected by the manual mock-registration advisory; 4.1.12 is the patched 4.x version. It concerns reachable mocker/dev-server functionality, not ordinary static dashboard requests. The full npm JSON also records the Windows redirect advisory and the other reported issues. [Maintainer advisory](https://github.com/vitest-dev/vitest/security/advisories/GHSA-qxg6-89mg-rqv8).

The dashboard Dockerfile builds in Node and serves only `dist` from nginx. Therefore the installed tooling and failing CI gate are confirmed; production browser exploitation of these advisories is **not** established. The successful October 19 scans predate the later advisory updates and do not replace today's failed check.

Required fix: update compatible resolutions to patched versions (at least Vite 6.4.4, Vitest/mocker 4.1.12 and Undici 7.30.1, subject to resolution and compatibility verification). Keep the existing audit threshold. Run a clean install, full audit, dashboard tests and production build. Do not close this by suppressing the audit or merely moving Vite to devDependencies.

Acceptance: clean lockfile install succeeds; both audit commands report the intended patched state; tests/build pass; the current commit has a successful fresh CI run.

### A24-02: Bind 2FA completion to the specific enrollment being confirmed

Sources: [read pending secret](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/AuthServiceImpl.java:220>), [complete enrollment](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/AuthServiceImpl.java:239>), [guarded update](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/repository/UserRepository.java:112>).

`enableTotp` loads pending secret A and verifies its code. A concurrent setup may save pending secret B and open B's enrollment before A completes. The final bulk update only requires a non-null pending secret and an unexpired enrollment; it does not compare an enrollment identifier or expected entity version. It installs the supplied old A secret, clears B and issues a fresh session.

The audit probe drives the real auth service and H2 repository. A spy inserts setup B's committed repository changes after real validation of A's valid TOTP. The final account is enabled with **A**, B is discarded, and an access token is returned. This is a deterministic reproduction of the interleaving, not a live concurrent HTTP attack. A valid authenticated flow, knowledge of A's valid code and overlapping setup/confirmation are prerequisites; unauthenticated takeover was not demonstrated.

AQ-04's version increment correctly protects a later stale entity save, but does not constrain this bulk update to the enrollment that was read.

Required fix: identify every enrollment with a nonce/version, and bind attempt spending, cancellation and completion to that identity atomically. A replacement or cancellation must make an old confirmation fail without consuming/replacing the new enrollment. An expected entity version can also enforce a compare-and-set design. Avoid comparing freshly encrypted randomized ciphertext as if it were deterministic plaintext.

Acceptance: pause enable(A), start setup(B), resume enable(A); A is rejected and B remains pending. Verify B can still complete, cancellation cannot resurrect A, and same-enrollment parallel confirmation still issues exactly one session. Repeat on PostgreSQL.

Evidence: [probe source](validation/TotpReplacementAuditTest.java), [probe log](validation/totp-replacement-probe.log). Its passing assertion confirms the defect, not a fix.

### A24-03: Select rollback from successful releases, not the preceding attempt

Sources: [automatic target](<D:/AIWA PROJECT/AIWA/deploy/deploy.sh:32>), [attempt recorded before startup](<D:/AIWA PROJECT/AIWA/deploy/deploy.sh:67>).

Every deployment attempt is appended before `compose up`. Automatic rollback simply selects the penultimate log row. With successful A followed by two failed attempts at B, the history is A/B/B, so `--rollback` selects B and prints a successful rollback message. The AP-04 guard prevents two successive rollback commands, but does not cover repeated failed deployments.

The probe executes the actual script with fake Git/Docker, creates fresh backup filenames, fails both build/start attempts and then permits `--no-build`. It records three compose starts tagged B; the rollback target is B rather than A. No checkout, container, database or deployment outside the temporary harness was changed.

Required fix: distinguish attempted, successful and failed releases, track the last healthy active release, and choose a different verified successful target for automatic rollback. Preserve failed-attempt backup records for diagnosis. Refuse automatic rollback when no good target is known rather than reporting the same failed revision as recovered.

Acceptance: A succeeds; B fails twice; automatic rollback starts A without rebuilding. Cover different failed revisions, failures before image creation, repeated deploy of the same SHA, and rollback after a prior rollback. Keep the existing no-backup/no-deploy guarantee.

Evidence: [probe source](validation/repeated-deploy-probe.sh), [probe log](validation/repeated-deploy-probe.log). Existing deploy harness still passes its 22 assertions.

### A24-04: Include CodeQL and Trivy in the deployment decision

Sources: [release-gate dependencies](<D:/AIWA PROJECT/AIWA/.github/workflows/ci.yml:279>), [deploy dependency](<D:/AIWA PROJECT/AIWA/.github/workflows/ci.yml:319>), [checker allowlist](<D:/AIWA PROJECT/AIWA/.github/scripts/check-ci-graph.mjs:14>), [CodeQL workflow](<D:/AIWA PROJECT/AIWA/.github/workflows/codeql.yml:18>), [Trivy workflow](<D:/AIWA PROJECT/AIWA/.github/workflows/scan.yml:17>).

The separate CodeQL and Security scan workflows run on main pushes, but `release-gate` does not depend on their results. The graph checker verifies only its explicit list of jobs in `ci.yml`, so it passes with both omitted. With staging configured, CI can deploy a main push while either security workflow is still running or has failed. Branch protection alone does not make an independently triggered push deployment wait for those workflows.

This is a source-confirmed path. The inspected CodeQL/Trivy runs themselves succeeded, and the inspected push's staging job was skipped; no bypassing deployment was triggered for the audit.

Required fix: make security checks reusable jobs called by CI and required by `release-gate`, or otherwise require successful scanner results for the exact deployment SHA before running the deployment. Extend graph/behavior checks so missing scanner prerequisites are rejected.

Acceptance: force either scanner to fail or cancel in a disposable CI test; deployment cannot start. A scan for a different SHA or a skipped scan must not satisfy the gate.

## Earlier Findings Rechecked

| Area | Current assessment |
| --- | --- |
| SEC-01 / SEC-02 | Authoritative DB checks on Redis misses and explicit failed logout revocation remain implemented; regression tests pass in the full backend suite. |
| SEC-03 | Expiry, attempt limits, one-time completion, pending-secret replacement and stale-save protection are implemented. A24-02 is a remaining replacement-race case. |
| SEC-04 / R6-02 | Pre-dispatch request ownership and owned auth events remain implemented; full mobile validation covers their host regressions. Native-device ordering remains a separate qualification. |
| Admin token storage | Access token is memory-only; refresh uses HttpOnly cookie. The old localStorage-token finding must not be repeated as current. |
| Production/encryption guards | Required encryption keys, provider/config guards and prod `open-in-view: false` are present. Runtime key custody was not inspected. |
| Admin permissions | Sensitive exports/read paths inspected use narrowed authorities. Existing RBAC tests pass. |
| RV-01 / AQ-05 location privacy | Public discovery and ETA calculations use the rounded home-provider pin. Reviewed tests pass. |
| RV-02 / AQ-02 deletion | Booking destination/listing scrub, waitlist deletion and audit actor replacement are present. Historical audit targets and retained accounting/safety data have documented limits. |
| AQ-01 / AQ-03 | Customer suspension cancellation/live-visit checks and review-only reject/request-info checks are implemented and covered by passing API tests. |
| Latest terms/theme changes | Role-targeted after-commit fan-out, terms landing, server error-code propagation and preference override are present. Host tests pass; cold-push/resume/navigation remains device smoke scope. |
| Recovery | Marker-based incomplete-recovery handling remains present. Existing host harnesses are separate from the new code-deploy rollback issue. |
| Secrets | Pattern scan checked 874 tracked text files, found 0 sensitive tracked filenames and only 2 known parser/generated-test-key markers. No entropy/full-history certification or ignored-secret inspection was performed. |

## CI Evidence And Remaining Launch Work

All links below refer to the audited SHA, not another branch:

- [October 16 push CI](https://github.com/alyaraf/AIWA/actions/runs/38944648556): success. Backend PostgreSQL/migration checks, backup/container restore harnesses, monitoring rules, Android, Flutter, admin, SBOM and release gate succeeded. Staging deployment was skipped. Job/step metadata is preserved in [github-ci-push.json](validation/github-ci-push.json).
- [October 19 scheduled CI](https://github.com/alyaraf/AIWA/actions/runs/39227362954): failure in Dependency-Check. The failed log explicitly says `NVD_API_KEY is not set: the scheduled/manual CVE scan cannot run`. It produced no dependency report. Other validation jobs succeeded; release/deploy were skipped for the scheduled event. [Failure log](validation/github-dependency-scan-failure.log).
- [October 19 CodeQL](https://github.com/alyaraf/AIWA/actions/runs/39235879859) and [Security scan](https://github.com/alyaraf/AIWA/actions/runs/39240509136): success. They are dated evidence and not proof against advisories indexed after those runs.

Existing blocker: configure `NVD_API_KEY` through the repository's secret-management path, set the documented `REQUIRE_CVE_SCAN=true` gate before promotion, then obtain a genuinely executed successful CVE scan/report. A green push job that explicitly skipped the scan is not clean vulnerability evidence. No secret value was requested or changed by this audit.

The 54 launch-signoff rows remain unsigned in the checked-in record. Actual CI evidence now exists for some rows, so the old blanket statement that no PostgreSQL/container/CI checks exist is incorrect. Offsite restore/key escrow, cloud IAM, provider delivery, actual staging health/load, native-device flows and ownership decisions still need their own evidence. This audit does not fill owner approval fields on someone's behalf.

## Validation

| Check | Result |
| --- | --- |
| Backend full suite, JDK 17 | **557 passed**, 0 failures/errors/skips; H2/mocked or in-memory dependencies. |
| Isolated 2FA probe | **1 passed**, confirming A24-02; actual service/repository with controlled scheduling. |
| Dashboard tests | **239 passed / 35 files** with Node 20 and two workers. |
| Dashboard production build | Pass; HTTPS synthetic API base and mocks disabled. |
| Full npm audit | Exit 1: 4 affected packages, 2 High / 2 Moderate. |
| CI production npm audit command | Exit 1: one High affected package (Vite). |
| Flutter analysis | No issues found. |
| Flutter full suite | **279 passed**, all tests completed successfully with two workers. |
| Deploy harness | 22 passed. |
| Backup harness | 47 passed; NTFS permission-mode assertions explicitly skipped by the harness. |
| Upload-swap / restore-flow harnesses | **83 / 93 passed**, respectively; both runs completed with 0 failed assertions. |
| CI graph self-test | Pass; 5 bad graph mutations rejected. A24-04 lies outside its current allowlist. |
| New rollback probe | Pass, confirming A24-03 using fake operations. |
| Credential pattern scan | 874 text files checked; no embedded credential confirmed. |

Commands, logs and probe instructions are in [validation/README.md](validation/README.md). An initial offline backend run could not resolve the newly pinned PostgreSQL driver; the subsequent online run fetched it and passed. An initial shell batch had an incorrect upload-test path after deploy/backup passed; the remaining harnesses were rerun using the correct path. These invocation failures are recorded, not classified as application defects.

No fresh local NVD scan, local container image/OS/Dart advisory scan, native Android/iOS smoke, browser penetration test, provider sandbox send, offsite restore drill or production load test was performed. GitHub results establish the specific remote jobs/steps described above, not all environment or launch gates. The Trivy workflow scans the filesystem; its success does not prove a production image/base-OS scan ran.

## Recommended Order

1. Patch the dashboard lockfile and make the current npm audit pass; configure/execute the backend CVE scan.
2. Bind all 2FA enrollment operations to an enrollment identity; add the replacement-race regression.
3. Track known-good releases and fix retry-aware automatic rollback.
4. Require exact-SHA CodeQL and Trivy success before deployment.
5. Repeat CI and the relevant staging/device/restore checks, then attach evidence and owner decisions to launch sign-off.

Application fixes, lockfile updates, deployment and external messages were not performed. Delivery is the audit, its fixtures/logs and a handoff update.
