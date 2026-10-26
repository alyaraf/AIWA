# Remediation record - post-change audit 2026-10-24

Date: 2026-10-26. Base: `main` at `23f285f` (audited SHA), changes **uncommitted** in the working tree. Nothing was committed, pushed, deployed or changed in any cloud setting; no live data was touched. The historical [audit](audit.md) and the defect probes in [validation/](validation/README.md) are unchanged (the probes keep asserting the old, faulty behaviour on purpose; the desired behaviour is now covered by the normal suites).

| ID | Status (local) | Still needs |
| --- | --- | --- |
| A24-01 | Fixed and verified locally | A green CI run on the pushed commit |
| A24-02 | Fixed and verified locally (H2) | The same suite on PostgreSQL 16 (CI job `backend`), migration V38 on a real database |
| A24-03 | Fixed and verified locally (fake Git/Docker) | Rehearsal on a real host (launch gate 54) |
| A24-04 | Fixed and verified locally (graph + decision tests) | A real CI run; a disposable failing/cancelled scan to watch the gate refuse; branch-protection check names updated |
| Backend CVE scan | Repository side done; **external configuration outstanding** | `NVD_API_KEY` secret, `REQUIRE_CVE_SCAN=true`, one genuinely executed scan |

## A24-01 - dashboard dependencies

`aiwa-admin-dashboard-updated/package.json` / `package-lock.json`:

| Package | Before | After |
| --- | --- | --- |
| vite (declared `^6.4.5`, stays a production dependency) | 6.4.3 | 6.4.5 (patched 6.x; 6.4.4 was the first fixed release) |
| vitest / @vitest/mocker (declared `^4.1.12`) | 4.1.11 | 4.1.12 |
| undici (transitive, via jsdom; lockfile-only) | 7.30.0 | 7.30.1 |

Enforcement is unchanged: CI still runs `npm audit --omit=dev --audit-level=high`; nothing was suppressed or moved between dependency groups.

Results (Node 20.20.2, npm 10.8.2): `rm -rf node_modules && npm ci` succeeded (151 packages); `npm audit` (all dependencies) **0 vulnerabilities**; the exact CI command `npm audit --omit=dev --audit-level=high` **exit 0, 0 vulnerabilities**; `npm test`: **239 passed / 35 files**; `npm run build` (HTTPS synthetic API base, mocks off): pass.

Registry note: this machine's npm default is an internal mirror (`nexus-front.tradenet.com`). Its audit service was not used; the audits above were run with `--registry=https://registry.npmjs.org` exactly as the audit's own commands do. `npm install` wrote the mirror's URL into 19 changed lockfile entries; those `resolved` hosts were restored to `https://registry.npmjs.org` (as in the other 182 entries) so CI can fetch them. Integrity hashes are npm's own and untouched. `npm ci` then succeeded from the lockfile. Review this lockfile diff before committing.

## A24-02 - 2FA enrollment identity

Every pending enrollment now has its own identity (`users.totp_enrollment_id`, random UUID per setup; migration `V38__totp_enrollment_identity.sql`, entity `User.totpEnrollmentId`, `updatable = false` like the other enrollment columns).

- `UserRepository.openTotpEnrollment(id, secret, enrollmentId, expiresAt)` installs secret, identity, fresh budget and expiry in **one** statement (it replaces the previous save + open pair, which left a window between them), bumps the version (AQ-04), clears the replay guard only when 2FA is not enabled, and leaves a confirmed secret / enabled 2FA untouched during re-setup.
- `claimTotpEnrollmentAttempt`, `completeTotpEnrollment` and `closeTotpEnrollment` all require `totp_enrollment_id = :enrollmentId`. An obsolete request therefore cannot spend the new budget, cancel the new enrollment, install the old secret or issue a session. No encrypted ciphertext is compared (the secret is only ever an assigned value).
- `AuthServiceImpl.enableTotp` reads the identity with the pending secret; a stale failure that finds its enrollment gone answers "expired" and leaves its replacement alone; budget exhaustion of the live enrollment still closes it and answers "too many attempts".
- The confirming code's time step is recorded only by the request that completed the enrollment (an obsolete request touches nothing).
- Compatibility: an enrollment that was pending before V38 has no identity, so it is refused as expired and setup must be restarted (at most a few minutes' worth of enrollments; no data loss).

Tests: new `TotpEnrollmentReplacementTest` (9 deterministic cases on the real service + repository, H2): replacement between validation and completion (the audit probe's interleaving), the replacement still confirmable afterwards, a stale wrong code not spending/cancelling the replacement, obsolete claim/close/complete each affecting 0 rows, cancellation not resurrectable, pre-V38 enrollment restarts, re-setup preserving the confirmed secret and its replay guard, setup clearing the stale guard when 2FA is off, and 4 parallel confirmations issuing exactly one session. Existing `TotpEnrollmentApiTest` (12, incl. attempt limits, expiry, replay, parallel confirmation, AQ-04) and `AdminTwoFactorEnrolmentApiTest` updated for the identity and pass.

Full backend suite, JDK 17.0.19: **566 tests, 0 failures, 0 errors, 0 skipped** (557 before + 9 new).

## A24-03 - rollback from a known-good release

`deploy/deploy.sh`: `backups/releases.log` stays one line per deploy **attempt**, written before the build (backup-before-deploy and the failed-attempt history are unchanged). New `backups/releases.good` gets `<utc time> <sha>` only after `compose up` succeeds (and after a successful rollback). Automatic `--rollback` picks the most recent known-good sha that differs from the current one (the sha of the log's last line), so A ok, B fails twice, rollback selects A; A ok, B fails, C fails selects A; A ok, B ok, C fails selects B.

- Refused clearly, before the checkout changes: no `releases.good` / no known-good release other than the current one (legacy logs are **not** guessed from: an attempt line is not proof it ran, so the first automatic rollback on an upgraded host needs the sha); and any target (also an explicit sha) whose `aiwa-*:<sha>` images are not on the host (`docker compose config --images` + `docker image inspect`). A start failure still reports `ROLLBACK FAILED` and records nothing.
- Unchanged: no build, backup or database work on rollback; the AP-04 refusal of a second consecutive automatic rollback.
- "Started" means `docker compose up` returned success; the script does not poll `/api/actuator/health`. Documented in `docs/release.md`.

Tests: `deploy/deploy_test.sh` 22 -> **38 assertions**, 0 failed (fake Git/Docker; also covers the same sha twice, B failing then succeeding, history without a good record, current-only good record, missing images).

## A24-04 - security scans are prerequisites of deployment

- `codeql.yml` and `scan.yml` are now **reusable workflows** (`workflow_call`, plus manual `workflow_dispatch`). `ci.yml` calls them as jobs `codeql` and `trivy`, with the same minimal permissions they had (`contents: read`; CodeQL also `actions: read`, `security-events: write`). Both left the independent `push` / `pull_request` / `schedule` triggers (ci.yml already runs on push, pull requests and weekly; keeping them would create unwaited duplicate runs). Remote Actions stay pinned to full SHAs; no secrets are passed.
- Each exposes `scanned_sha` (the `git rev-parse HEAD` of what it scanned, asserted equal to `GITHUB_SHA`). `release-gate` now `needs` both, and runs `.github/scripts/evaluate-release-gate.mjs` (replacing the inline jq): every required job must be `success` (failed / cancelled / skipped / missing refuses), CodeQL and Trivy must report the released commit (a different or missing sha refuses), and `REQUIRE_CVE_SCAN=true` refuses a skipped backend CVE scan. `deploy-staging` still depends on the gate only; the graph check proves its transitive needs include both scans.
- `check-ci-graph.mjs`: `codeql` and `trivy` are REQUIRED jobs; additionally checks that they call the local reusable workflows with no job-level condition, that those declare `workflow_call` and `scanned_sha` with no `continue-on-error`, that every remote Action is pinned to a 40-hex SHA, that there is no `pull_request_target`, and that the gate runs the decision script and passes `vars.REQUIRE_CVE_SCAN` to it. Self-test mutations grew from 5 to **18**, all rejected.
- Tests: `.github/scripts/evaluate-release-gate.test.mjs` (**18 tests**, run in the `ci-graph` job): each scanner failed / cancelled / skipped / absent / other-commit / no-commit, an unknown released sha, every other job failing, CVE-scan skipped with and without `REQUIRE_CVE_SCAN`, and the real CLI's exit codes.
- Operational effect: the old standalone check names ("CodeQL / analyze (...)", "Security scan / trivy") become `codeql / ...` and `trivy / trivy` inside the CI workflow. If branch protection requires the old names, update it.

## Backend vulnerability scanning

Already in the repository and re-checked: the `dependency-scan` job reads `secrets.NVD_API_KEY`, runs OWASP Dependency-Check with `failBuildOnCVSS=7`, exposes `scan=ran|skipped`, and the gate reports it. Added: the job also receives `REQUIRE_CVE_SCAN`, so on a push with the variable `true` and no key the **scan job itself fails** (not only the gate); the gate decision is covered by tests above. Not changed: with no key and no requirement, a push still ends `skipped` with a warning and the gate passes, which is the documented pre-production behaviour; it is never reported as a pass.

**External requirements (not done here, no secret was created, read or printed):**

1. Create the repository secret `NVD_API_KEY` (free key, https://nvd.nist.gov/developers/request-an-api-key) through the normal secret-management path.
2. Set the repository variable `REQUIRE_CVE_SCAN=true` before any production promotion.
3. Run CI on `main` (or `workflow_dispatch`) and confirm the `dependency-scan` job step summary says "ran, no CVSS >= 7 finding" and the gate summary shows `backend CVE scan: ran`. The 19 October run failed for the missing key; there is still no successful scan evidence.
4. Confirm branch protection / required checks use the new job names (above).
5. Ongoing: the Trivy action scans the filesystem; a container-image / base-OS scan is not part of it.

## Other verification (local)

| Check | Result |
| --- | --- |
| Backend, JDK 17, full suite | 566 passed, 0 failed |
| Dashboard: clean `npm ci`, both audits, tests, build | 0 vulnerabilities / exit 0 / 239 passed / build pass |
| `deploy/deploy_test.sh` | 38 passed |
| `deploy/backup/backup_test.sh` | 47 passed (NTFS mode assertions skipped by the harness) |
| `deploy/backup/uploads_swap_test.sh` | 83 passed |
| `deploy/restore_flow_test.sh` | see HANDOFF.md (run last; result recorded there) |
| `check-ci-graph.mjs --self-test` | OK, 18 mutations rejected |
| `evaluate-release-gate.test.mjs` | 18 passed |
| Flutter | not run: no mobile code changed |

Not verified locally: real GitHub Actions execution (the workflow YAML was not run through actionlint or GitHub; reusable-workflow permissions and output wiring are checked by the graph tests and by reading, not by a run), PostgreSQL 16 for V38 and the 2FA suite, a real-host rollback, staging and production.
