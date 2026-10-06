# Round 5 verification coverage

Date/commit: 2026-10-06 / ddebaf9e40d7fd1a071888a490aea23715e6d2bd. Source root: D:/AIWA PROJECT/AIWA.

## Inputs and isolation

HANDOFF.md and the round 4 remediation/history were read before verification. The diff from 290a05f to ddebaf9 includes six committed changes across backend, dashboard, mobile, recovery, CI and documentation. No applicable AGENTS.md was found in the inspected project/parent paths. No subagents were started.

Tracked backend source/tests/resources/pom, dashboard source/config/lockfiles/assets, Flutter lib/test/integration_test/assets/pubspec/l10n/analyzer files, deployment and CI inputs were copied into:

`C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r5/snapshot`

Dependencies came from the already available audit copy and installed Flutter cache; native build output/package installs were not claimed. 687 tracked copied inputs match the live project byte-for-byte (source-manifest.tsv). The manifest records snapshot inputs, not every repository file or external dependency binary. The tests and three code probes ran in that disposable copy.

## Reviewed changes

| Area | Reviewed paths / available tests |
| --- | --- |
| Backend | SafetyService/SOS DTO and snapshot fixtures; AdminController/ComplaintController; search repositories/services/Searches; User ORM graphs/batching; gateway receipt checks; V34 schema/backfill rehearsal and compatibility tests |
| Admin | App storage-event/session reset and permission loading; restricted routing; API private blob lifecycle; SafetyQueue ordering/filter/action/freshness; server-paged Complaints/Flags/Reviews; cross-tab/blob/order/paging tests |
| Mobile | SecureStorage attempts/lock and AuthRepository/AuthBloc; existing ApiClient refresh; destination amendment sheet/flow; provider setup checkpoint/runner/pending page; terms reload; new race/amend/resume/widget tests |
| Recovery | backup encryption/verification/retention/reconciliation and manifest; uploads swap rollback/journal/exit states; outer restore safety/encryption/preflight/restart/manual undo; real script fault harnesses |
| CI | release-gate/deploy dependencies and result checks; scan ran/skipped output and REQUIRE_CVE_SCAN; local graph checker and five negative mutations; existing mandatory npm High audit |
| API | Static current controller inventory regenerated: 183 handlers / 29 controllers, metadata/parameters/validation and reachable calls. Static analysis does not resolve every framework/ORM/integration behavior. |

## Commands and environment

- Backend, from snapshot/aiwa-backend: JDK 17.0.19; `mvn.cmd -B -o -Dmaven.repo.local=C:\Users\fsherif\.m2\repository test`.
- Dashboard, from snapshot/aiwa-admin-dashboard-updated: Node 20.20.2; `npm test -- --run`, `npm run build`; after explicit user approval, `npm audit --omit=dev --json --registry=https://registry.npmjs.org` and local `npm ls source-map-js --omit=dev`.
- Flutter, from snapshot/Android/aiwa_app: installed SDK 3.47.5 / Dart 3.13.4, PUB_CACHE D:/tools/pubcache; `flutter analyze --no-pub`, `flutter test --no-pub --reporter expanded`; audit fixture run separately by explicit file path.
- Git Bash, from snapshot: backup_test.sh, uploads_swap_test.sh and restore_flow_test.sh; then audit-only pair and undo harnesses. /usr/bin and /bin prepended to PATH; TMPDIR inside the audit staging root.
- CI graph: `node .github/scripts/check-ci-graph.mjs --self-test`.
- Environment: fresh `docker version` could not connect to the Linux engine named pipe; psql/promtool not found. No engine/service startup or live restore was attempted.

Windows sandbox permissions blocked Node file resolution and Flutter's SDK lock file. Those commands were rerun with reviewed escalation; only the audit-owned stalled Flutter launcher was stopped. Automatic review initially rejected the npm external check; the user then expressly authorized dependency-only metadata egress and the retry completed with one High upstream advisory. These tooling restrictions are not application defects.

## Boundaries

No fresh native-browser/device/Android release/iOS archive/load/provider/cloud/offsite/CI execution is claimed. Cached iOS secure-storage source was inspected to qualify the refresh write ordering; the deterministic Dart test models concurrency and does not replace an iOS device reproduction. The build dependency advisory was verified against the upstream advisory and maintainer release; no malicious-input denial-of-service exploit was run.

Existing full suites pass, but targeted probes reveal gaps their tests do not cover. Previously fixed findings outside changed paths were not independently exercised one by one. All 40 launch-signoff evidence rows remain incomplete. Only audit files and HANDOFF.md are written into the project.
