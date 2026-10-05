# Remediation verification log — 2026-10-05

Commands run on the developer machine (Windows 11) after the round 3 remediation. Synthetic data only; no production
system, credential or deployed service was touched. Counts are copied from the tools' own summaries.

| Check | Command (from the repository root) | Result |
| --- | --- | --- |
| Backend, JDK 17.0.19.10 | `cd aiwa-backend && mvn -o test` | `Tests run: 483, Failures: 0, Errors: 0, Skipped: 0` — BUILD SUCCESS (baseline 411) |
| Backend targeted | `mvn -o -q test -Dtest=...` per fix | each class green before the full run |
| Contract snapshot | `mvn -o test -Dtest=ApiContractSnapshotTest -Dapi.contract.update=true` once, then plain | 183 operations, 169 schemas recorded; later runs compare against them |
| Admin, Node 20.20.2 | `cd aiwa-admin-dashboard-updated && npx vitest run` | `Test Files 28 passed (28)`, `Tests 164 passed (164)` (baseline 120) |
| Admin build | `npx vite build` | built; `index-*.js` 345.82 kB (gzip 100.54 kB), CSS 49.90 kB |
| Admin advisory scan | `npm audit --omit=dev --audit-level=high` | **could not run**: `audit endpoint returned an error`. `package.json` and the lockfile are unchanged by this work, so the audited result of 0 vulnerabilities still describes the same dependency set; re-run when the endpoint answers |
| Flutter analyze | `cd Android/aiwa_app && flutter analyze` (Flutter 3.47.5, Dart 3.13.4, `PUB_CACHE=D:\tools\pubcache`) | `No issues found` |
| Flutter tests | `flutter test` | `+221: All tests passed!` including the English/Arabic goldens (baseline 178) |
| Backup harness | `bash deploy/backup/backup_test.sh` | `32 passed, 0 failed` (NTFS mode assertion skipped as before) |
| Staged-uploads failure injection | `bash deploy/backup/uploads_swap_test.sh` | `33 passed, 0 failed` |
| Restore order with a fake docker | `bash deploy/restore_flow_test.sh` | `23 passed, 0 failed` |
| Real-browser check | Vite dev server, `VITE_USE_MOCKS=true`, the desktop app's built-in browser | Flags → confirm dialog: `role=alertdialog`, named, `aria-modal`, `#root` inert + `aria-hidden`, focus inside the dialog; Escape closes it, restores focus to "Send warning" and removes inert. Bookings row: `role=button`, `tabindex=0`, `aria-expanded` false → true on Enter, detail panel shown. Safety: after an `offline` event the `role=alert` banner appears, the tags read "Not live · updated hh:mm:ss" and "1 open (as of last update)", "No open SOS alerts" is not claimed. The first Bookings visit crashed with `Cannot access 'refreshTick' before initialization` (a hook declared after its use); fixed, and `App.screens.smoke.test.jsx` now fails on that crash (verified by reintroducing it) |

## Not run, and why

| Check | Reason |
| --- | --- |
| PostgreSQL 16 / Redis (Flyway V34 on the real engine, concurrency) | Docker Desktop did not start (`dockerDesktopLinuxEngine` pipe missing) and no local PostgreSQL is installed. V34 ran against H2 in PostgreSQL mode in `MigrationSchemaValidationTest` only |
| promtool (`alerts_test.yml`) | needs the Prometheus image or binary; the `monitoring-rules` CI job runs it |
| `deploy/restore_test.sh` (real PostgreSQL restore) | needs Docker |
| GitHub Actions jobs (new and old), NVD scan, image scan, SBOM | CI only |
| Devices, signed archives, provider sandboxes, k6, soak, cloud/bucket checks, secret/history scan | external access or hardware required |

## Evidence that the new tests exercise the defects

- M-03: `api_client_session_test.dart` "multipart upload … replayed" fails with `ServerException` when the `FormData.clone()` line
  is commented out, passes with it.
- Admin Bookings crash: `App.screens.smoke.test.jsx` fails with `Cannot access 'refreshTick' before initialization` when the
  hook order is reverted, passes with the fix.
- I-02: `uploads_swap_test.sh` first run caught a real bug in the journal handling (a bookkeeping file moved back into the live
  volume after a rollback); fixed before the numbers above.
