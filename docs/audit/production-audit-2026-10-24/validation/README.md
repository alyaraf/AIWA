# Audit validation - 2026-10-24

Audited AIWA SHA: `23f285f10e49d5aca97025f3322fa844a04af6a5`.
Logs were captured on the host with JDK 17.0.19, Node 20.20.2, Flutter installed at `D:/tools/flutter`, pub cache `D:/tools/pubcache`, and Git Bash.

## Existing Tests

Run from the corresponding project directory:

```powershell
# aiwa-backend; JAVA_HOME set to the installed JDK 17
mvn -B -ntp test '-DargLine=-Xmx1400m -XX:MaxMetaspaceSize=384m -Xss512k'

# aiwa-admin-dashboard-updated; Node 20
npm test -- --maxWorkers=2
# Build was run with VITE_API_BASE_URL=https://audit.example.invalid/api and VITE_USE_MOCKS=false.
npm run build
npm audit --json --registry=https://registry.npmjs.org
npm audit --omit=dev --audit-level=high --json --registry=https://registry.npmjs.org

# Android/aiwa_app; installed Flutter and PUB_CACHE
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 --reporter expanded --timeout 120s

# Project root, Git Bash for shell harnesses
bash deploy/deploy_test.sh
bash deploy/backup/backup_test.sh
bash deploy/backup/uploads_swap_test.sh
bash deploy/restore_flow_test.sh
node .github/scripts/check-ci-graph.mjs --self-test
```

Backend logs use H2 and in-memory/mocked dependencies. Shell harnesses use temporary files and fake operations; they do not establish Linux permission behavior or live restore reliability. Dashboard logs include jsdom's pre-existing `scrollTo` warnings.

## Defect Probes

Both probes assert the observed faulty behavior. A passing probe is evidence of a defect, not a security regression test passing its desired behavior.

`repeated-deploy-probe.sh` accepts an absolute path to the audited `deploy.sh`. It copies that script into a temporary folder, shadows Git and Docker with fakes, reproduces two failed B deployments followed by rollback and asserts the incorrect B target. It never operates on a real checkout or Docker daemon.

```bash
bash repeated-deploy-probe.sh 'D:/AIWA PROJECT/AIWA/deploy/deploy.sh'
```

`TotpReplacementAuditTest.java` was copied into a disposable `git archive` snapshot of the backend at the audited SHA, under `src/test/java/com/aiwa/api/`. The real auth service and H2 repository execute; a TotpService spy performs a real verification and inserts the competing setup's committed state at the controlled interleaving point. No original project test/source file was added or changed.

```powershell
# In the disposable backend snapshot, with the fixture added and JDK 17 active:
mvn -B -o -ntp test -Dtest=TotpReplacementAuditTest '-DargLine=-Xmx900m -XX:MaxMetaspaceSize=320m -Xss512k'
```

## Evidence Files

- `backend-tests.log`: initial offline dependency-resolution failure.
- `backend-tests-online.log`: complete current backend suite.
- `admin-tests.log`, `admin-build.log`: current dashboard results.
- `npm-audit.json`, `npm-audit-production.json`: fresh advisory-service responses, including advisory IDs and fixed-version information where supplied.
- `flutter-analyze.log`, `flutter-tests.log`: current host mobile validation.
- `shell-tests.log`: deploy and backup results, then an invocation-path error.
- `recovery-tests.log`: corrected upload-swap and restore-flow runs.
- `ci-graph.log`: current checker and mutation checks.
- `repeated-deploy-probe.log`, `totp-replacement-probe.log`: newly reproduced defects.
- `github-ci-push.json`: job/step metadata for the audited SHA's successful push CI.
- `github-dependency-scan-failure.log`: failed scheduled scan, explicitly missing NVD key.
- `Scan-Secrets.ps1`, `secret-scan.txt`: tracked-file pattern scanner reused from the prior audit with output placed beside the script; matching values are redacted.
- `source-manifest.tsv`: SHA-256 hashes of 19 selected source/configuration inputs used for the findings and closure checks; not an inventory of the entire repository.

Credential scan scope excludes entropy analysis, complete Git history, binaries and ignored deployment-secret contents. No credential was changed. GitHub metadata/logs are dated evidence read during the audit; no workflow was triggered, rerun, edited or approved.
