# Coverage and validation boundary — round 4

Date 2026-10-05. Project D:/AIWA PROJECT/AIWA. Baseline 290a05f0606545c073c22e1753cc9ad5c584fa5a, branch main, clean application working tree. Compared against ac67446495a22ce11b8f2071d0f1599f3c0cdee4. Six remediation commits are now committed; the old HANDOFF statement that they were uncommitted was stale.

## Scope and method

This re-audit carries forward the round 3 whole-project architecture review and rechecks updated material source/config/test paths, prior finding paths, all current controller mappings/DTO constraints and critical consumers. It is not a claim that every unchanged line was independently re-reviewed or that every endpoint was dynamically exercised.

The repository has 801 tracked paths at this baseline. Material entity/repository/controller/migration and integration boundaries are reviewed with fresh source inventory plus the prior historical coverage. Generated build output, dependency caches, binary assets and ignored credential values are not semantically certified. source-manifest.tsv lists tracked material text source/config/tests/docs and hashes before audit delivery; hashes are an integrity aid, not proof of correct behavior.

| Area | Review focus | Evidence / limits |
| --- | --- | --- |
| Mobile | All changed lib paths; auth/session/cache, router/onboarding/terms, bookings/notifications paging, upload retry, provider buffer, push launches | Clean analyzer, 221 host tests incl. goldens, two new isolated race probes; no devices/release build |
| Backend API/security | All 29 controllers/183 mapped handlers inventoried; changed method gates/projections/guards/tokens/integrations; owner/state flows and prior findings rechecked | 483 test assertions green; mapper probe confirms SOS mismatch; no deployed JWT/MFA account matrix |
| Database | 28 entity files/26 repositories; previous constraints/locks plus V34 and changed mutation flows | H2 tests/migration validation; no live PostgreSQL/explain/concurrency or production-copy V34 |
| Dashboard | Changed App/API/shared primitives and previous screen findings; queue/session/body/action/refresh races | 164 tests/build, three probes; no fresh native-browser/screen-reader/cookie pass |
| Operations | Backup/swap/restore/reconcile, retention/offsite, alert selectors/tests, compose/Docker/CI deltas and launch/runbook docs | 32/33/23 existing shell checks; OS rollback and outer-flow probes; no Docker daemon/promtool/live volume |
| Integrations | Gateway refusal/URL and log hygiene, FCM outcome, onboarding/delivery boundaries | Unit tests; no SMS/email/FCM/cloud request sent |
| Dependency governance | Unchanged lock/manifests, new contract/SBOM job and audit | npm production advisory scan 0; no backend CVE scan, native artifact/license scan or executed SBOM job |

## Executed commands

All builds/test writes occurred in:
C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r4/snapshot

| Command | Fresh result |
| --- | --- |
| JDK17 Maven: mvn.cmd -B -o -Dmaven.repo.local=C:/Users/fsherif/.m2/repository test | 483 tests, 0 failed/errors/skipped; BUILD SUCCESS |
| Node20 npm test; npm run build | 164 / 28 files; build success, 1576 modules, 345.82 kB JS / 100.54 kB gzip |
| npm audit --omit=dev --audit-level=high --registry=https://registry.npmjs.org --json | Exit 0, 0 vulnerabilities |
| Flutter analyze --no-pub | No issues found |
| Flutter test --no-pub --exclude-tags audit-probe | Existing 221 tests pass |
| bash deploy/backup/backup_test.sh | 32 checks pass |
| bash deploy/backup/uploads_swap_test.sh | 33 checks pass |
| bash deploy/restore_flow_test.sh | 23 checks pass |
| Maven -Dtest=SafetyDestinationAuditProbeTest test | 1 intentional-defect assertion passes |
| Vitest r4.audit.test.jsx; r4.sos.audit.test.jsx --maxWorkers=1 | 2 + 1 intentional-defect assertions pass |
| Flutter test --no-pub test/r4_audit_auth_test.dart | 2 intentional-defect assertions pass |
| rollback_probe.sh and extended outer restore harness | Missing live old file, false rollback success, restart despite failed file recovery; retained plaintext safety copy confirmed |

JAVA_HOME used C:/Program Files/Eclipse Adoptium/jdk-17.0.19.10-hotspot; Node C:/Users/fsherif/AppData/Local/nvm/v20.20.2; Flutter D:/tools/flutter; PUB_CACHE D:/tools/pubcache. Cached dependencies were copied/reused without changing project locks.

Environmental/fixture problems are not application failures: the initial audit-only Dart fixture contained print statements flagged by the analyzer; they were removed and the final analyzer passed. The first cross-tab reproduction had overly exact selectors for quoted/prefixed text; corrected selectors reproduced the defect. The configured corporate npm audit registry failed DNS; an explicit public-registry read succeeded. Docker Linux engine connection failed even with permitted access. Synthetic shell chmod/mode behavior on NTFS does not certify Linux permissions. Existing Vitest jsdom emits unimplemented scrollTo warnings.

No application remediation occurred. Audit-only fixture sources are rendered in validation/probe-fixtures.md, outside the application's test directories in the delivered report. Raw evidence names/results are indexed in [validation/README.md](validation/README.md).

## Unexecuted verification

Real PostgreSQL/Redis, promtool, compose startup or a real restore were not run because Docker Desktop's Linux engine is unavailable. No CI job, backend dependency-check/NVD feed, signed mobile release, physical device, native-browser session, real provider sandbox, cloud IAM/object retention, offsite-only restore or load/availability test was executed. Preserve these as open launch gates; do not equate authored scripts/policies with execution.
