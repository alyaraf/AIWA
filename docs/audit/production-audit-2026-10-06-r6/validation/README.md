# Round 6 fresh validation and defect fixtures

Audited commit: b2d70b93399ac318d4aa7ce83533f9d6bf485827. Date: 2026-10-06. Project application files were not edited by the audit.

| File | Evidence |
| --- | --- |
| baseline.txt / ../source-manifest.tsv | Clean initial application HEAD; 691 copied input hashes match |
| backend-tests.txt | 506 tests, no failures/errors/skips; H2, not PostgreSQL/Redis |
| admin-install.txt / dependency-tree.txt | Clean offline ignore-scripts installation and source-map-js 1.2.2 via Vite/PostCSS |
| admin-advisories-public.json | Fresh approved public production advisory scan, 0 reported vulnerabilities, exit 0 |
| admin-tests.txt / admin-build.txt | 221 tests / 33 files and production build |
| flutter-analyze.txt / flutter-tests.txt | Analyzer clean, 253 tests; excludes audit-only fixture |
| shell-checks.txt | Backup 47 / uploads swap 83 / outer restore 67 checks; NTFS chmod checks skipped |
| ci-graph.txt | Dependency graph passes, five bad graph mutations rejected; not a CI run |
| retry-probe.txt / r6_retry_audit.sh | R6-01: extended outer harness with two assertions; 69 total. Failed file undo, then failed safety dump on retry produces backend start with mixed generations. |
| stale-lock-probe.txt / r6_stale_lock_audit_test.dart | R6-02: A delayed HTTP 423 ends authenticated B through the actual client/repository/storage/bloc and mirrored root handler |
| safety-search-probe.txt / r6-safety-audit.test.js | R6-03: open alert visible unfiltered; zero search matches suppress unfiltered oldest request/result |
| environment.txt | Missing Docker Linux engine pipe; psql/promtool absent on PATH |

Passing audit-only probes assert defects, not repairs. Their normal test filenames were moved out before the baseline suites.

## Reproduction

Use a **disposable checkout** with dependencies for the audited commit. Never reproduce this by restoring live data.

1. Put r6_retry_audit.sh in disposable deploy/ and run it with Bash. It embeds the source restore_flow_test.sh harness plus the added case, creates a fake Docker executable and private temporary volume, and deletes only its own temporary work. No containers or database are contacted.
2. Put r6_stale_lock_audit_test.dart in disposable Android/aiwa_app/test/ and run `flutter test --no-pub test/r6_stale_lock_audit_test.dart --reporter expanded`. The delayed request is sent as A; the real AuthBloc signs in B; returning A's 423 triggers B logout through the listener copied from _ThemedAppState's current branch. All identities/tokens are synthetic.
3. Put r6-safety-audit.test.js in disposable dashboard src/test/ and run Vitest on that file. The fake API has one global open alert but no matches for the search; an unfiltered helper call demonstrates the alert first, then the filtered helper returns oldest null without querying the global queue.
4. Convert these assertions into expected-correctness regressions after fixes. Retain all current source suites, and execute actual platform/staging checks separately.

Existing jsdom scrollTo and mocked Flutter integration warnings are present in baseline logs; test counts/exit results are recorded. No production exploitation, actual user-data loss, provider delivery, native navigation or cloud verification is claimed.
