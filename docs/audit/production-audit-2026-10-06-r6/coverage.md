# Round 6 coverage and commands

Date: 2026-10-06. Application HEAD: b2d70b93399ac318d4aa7ce83533f9d6bf485827. Source root: D:/AIWA PROJECT/AIWA. The six committed remediation changes after ddebaf9 were reviewed; the starting tree was clean. HANDOFF.md and remediation.md incorrectly call that work uncommitted; the current audit/handoff supersede that metadata.

HANDOFF and the previous audit/remediation were read first. No applicable AGENTS.md was found in the inspected project/parent paths. No subagents were started.

## Isolation

Tracked backend source/tests/resources/pom, dashboard source/config/lock/assets, Flutter lib/test/integration/assets/pubspec/l10n/analyzer files, deploy and CI were copied to:

`C:/Users/fsherif/.codex/visualizations/2026/10/05/01a10bf7-f91b-7363-9de4-71d88794cf43/audit-work-r6/snapshot`

691 copied tracked inputs match the project SHA-256 byte-for-byte. The manifest covers snapshot inputs, not every repository file or external dependency binary. Node dependencies were clean-installed from local npm cache using the committed lockfile. Flutter uses the installed SDK/cache. Probes were isolated and excluded from the normal baseline tests.

## Reviewed areas

- Mobile: credential methods/lock, refresh generation/future ownership, conditional clearing and startup, AuthBloc transitions, error interceptor and _ThemedAppState event consumption, seven new session tests and adapted existing test.
- Recovery: scratch dump reference extraction, cleanup/failure reporting, preserved encryption/retention, paired undo preflight/safety/transaction/files/restart, uploads status/journal/rollback, failure/undo fixtures and retry behavior.
- Dashboard/backend: six paged adapter routes, query filters/counts/permissions, search repositories/controllers/services, optimistic actions/refill and empty-page correction, SOS context/sequence/freshness and oldest banner, changed/new tests.
- Dependencies/CI: exact lockfile patch, clean installation, resolved tree, fresh production advisory gate, unchanged mandatory High audit and release graph with five negative mutations.
- APIs: 183 current handler methods / 29 controllers regenerated from source. Parameters/authorization/validation/reachable operations are static inventory rather than full runtime tests.

## Commands

- JDK 17.0.19, snapshot/aiwa-backend: `mvn.cmd -B -o -Dmaven.repo.local=C:\Users\fsherif\.m2\repository test`.
- Node 20.20.2, snapshot/aiwa-admin-dashboard-updated: `npm ci --offline --ignore-scripts`, `npm test -- --run`, `npm run build`, `npm ls source-map-js --omit=dev`.
- Fresh approved scan: `npm audit --omit=dev --audit-level=high --json --registry=https://registry.npmjs.org`. No package/lock/npmrc modification or registry change was made.
- Flutter 3.47.5/Dart 3.13.4, PUB_CACHE D:/tools/pubcache: `flutter analyze --no-pub`, `flutter test --no-pub --reporter expanded`; separate audit fixture file run.
- Git Bash: backup_test.sh, uploads_swap_test.sh, restore_flow_test.sh; audit-only r6_retry_audit.sh. PATH prepended /usr/bin:/bin; TMPDIR inside audit staging. Fake Docker/database calls, no live restore.
- Node: `.github/scripts/check-ci-graph.mjs --self-test`; separate one-file Vitest SOS reproduction.
- Read-only environment: `docker version` failed on the absent Linux engine named pipe; psql/promtool not found.

The first Maven attempt could not read a cached Micrometer jar under sandbox permissions; it was rerun with reviewed escalation and completed successfully. Node/Flutter tools needed reviewed filesystem escalation as in prior audits. Maven and full Vitest were not run simultaneously. Public dependency-only metadata egress was already explicitly authorized in this chat; no new approval question was needed.

## Limits

No native browser/device/release archive/real PostgreSQL/Redis/container recovery/promtool/CI/provider/cloud/offsite/load execution is claimed. The Flutter defect test uses the real bloc/repository/storage wrapper and delayed HTTP test double, with an event listener mirroring _ThemedAppState's branch; it does not mount native routing. The shell harness models database generations and real file content, not actual PostgreSQL/container behavior. The SOS helper reproduction plus render source establish the missing banner without a native-browser run.

Previously fixed findings outside changed paths were not individually re-executed. Green baseline suites and green dependency data are limited evidence; the three targeted defect assertions still pass. Delivery changes only audit files and HANDOFF.md.
