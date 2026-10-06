# Fresh round 5 evidence

Audited application commit: ddebaf9e40d7fd1a071888a490aea23715e6d2bd. Date: 2026-10-06. All source tests, builds and fault models run in a disposable snapshot; production code was not patched.

| File | Meaning |
| --- | --- |
| baseline.txt / ../source-manifest.tsv | Clean initial HEAD, 687 exact copied inputs |
| backend-tests.txt | 498 backend tests; H2/test dependencies; includes snapshot/search/query-count/receipt/V34 rehearsal |
| admin-tests.txt / admin-build.txt | 193 jsdom tests, production build output |
| flutter-analyze.txt / flutter-tests.txt | Clean analyzer and 246 host tests, excluding the audit-only fixture |
| shell-checks.txt | Backup 41 / swap 79 / outer restore 45 assertions; NTFS chmod checks skipped |
| ci-graph.txt | Full static deploy dependency reachability, five rejected graph mutations |
| refresh-probe.txt / r5_refresh_audit_test.dart | R5-01 defect reproduction; synthetic tokens/API and delayed storage, not real accounts/device |
| backup-undo-probes.txt / r5_pair_audit.sh | R5-02 saved-reference deletion model; actual backup/reconciliation scripts, stub database commands |
| backup-undo-probes.txt / r5_undo_audit.sh | R5-03 existing outer-flow harness extended by 3 defect assertions; fake Docker and disposable volume |
| admin-advisories-public.json / dependency-tree.txt | Approved fresh public npm check: source-map-js 1.2.1, one High upstream advisory; audit exit 1; local Vite→PostCSS dependency path |
| environment.txt | Fresh unavailable Docker Linux engine / absent psql/promtool evidence |
| flutter-platform-ordering.txt | Locked cached storage plugin paths/hashes and iOS concurrent-queue / Android serialized-worker evidence; not a device test |

## Reproduce safely

Use a **disposable checkout** of the audited commit with its normal dependencies. Do not run restore.sh against a live deployment to reproduce this report.

1. Copy r5_refresh_audit_test.dart into the disposable Flutter test/ directory and run `flutter test --no-pub test/r5_refresh_audit_test.dart --reporter expanded`. It succeeds only when A's delayed refresh corrupts B's credentials; the adapter returns B's payload when it sees B's token. Its undeclared `audit-probe` tag emits a warning but does not invalidate the run. Remove it from the normal test location after verification.
2. Copy r5_pair_audit.sh into disposable deploy/backup/ and run it with Bash. The fixture creates/deletes only its own temporary files. Database commands are stubs; dump content represents the reference snapshot. It proves the actual backup script queries the later live state and records a false clean result; it is not a real PostgreSQL dump/restore test.
3. Copy r5_undo_audit.sh into disposable deploy/ and run it with Bash. It incorporates the source restore_flow_test.sh harness plus scenario U. The log proves a restart occurs after restoring the old database while the new avatar remains live, before the file undo command.
4. After fixes, invert the defect assertions into meaningful regressions and retain the existing source suites. Run real iOS, PostgreSQL/container recovery, Linux modes and CI checks separately.

Warnings from mocked notification/Sentry APIs and jsdom scrollTo appear in existing suites; their zero exit status/test totals are recorded. Nothing here proves production readiness or closes the launch sign-offs.
