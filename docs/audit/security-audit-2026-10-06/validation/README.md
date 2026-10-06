# Security audit evidence — 6 October 2026

All application execution occurred in a disposable snapshot under the audit staging directory. Application edits were made by the user's ongoing implementation work; this auditor only copied source, ran tests and prepared these report files. HEAD was `b2d70b93399ac318d4aa7ce83533f9d6bf485827`; use the final manifest for the additional working-tree source.

## Results

| Evidence | What it establishes |
| --- | --- |
| backend-security-final.txt | Final targeted backend security run after correcting a test-fixture setup error: 114 tests, zero failures/errors/skips. Contains 111 existing regressions and three defect probes. |
| backend-security-initial.txt | Original selected run: all 111 existing tests and the TOTP audit probe passed; one revocation probe failed because its mock falsely said the token was already in the database before the tested write. The audit fixture was corrected, not application source. This log is retained and is not presented as a passing build. |
| backend-probes-controller.txt | Two corrected revocation probes pass, including real-controller response status; fake Redis/repository failures, not full HTTP or live outage injection. |
| backend-latest-moderation.txt | Latest-source RBAC/privacy/query checks following moderation changes: 14 tests pass, zero failures/errors/skips. Twelve repeat earlier regressions; two query checks complete this run. |
| backend-latest-moderation-memory-failure.txt / backend-latest-moderation-low-memory-failure.txt | Two resource failures before those tests could run: native allocation during compilation, then inability to reserve the separate test JVM's heap. The final run passed in a single bounded JVM. These are not application assertion failures. |
| SecurityRevocationAuditTest.java | Audit-only reproduction of SEC-01 and SEC-02. Tests assert the observed defects; convert their assertions when fixing behavior. |
| SecurityTotpAuditApiTest.java | SEC-03 Spring/MockMvc reproduction with a synthetic enabled admin, H2 and in-memory Redis. |
| security_request_owner_audit_test.dart | SEC-04: host secure-storage read ordering model and actual ApiClient/Dio transport recording. |
| flutter-security-focused.txt | 37 passing tests: one defect probe plus 36 current session/attempt/refresh regressions, including 12 new R6 session-event tests. |
| flutter-analyze.txt | Clean Flutter analyzer result. |
| flutter-tests-incomplete.txt | Full-suite attempt reached +230 progress, then stopped producing output. The audit's own Dart PID was terminated after verifying its parent wrapper. Another worker's Flutter process was left untouched. The log's final failure reflects termination; full-suite completion is unverified. |
| dashboard-current-full.txt / dashboard-current-build.txt | Latest working-tree dashboard: 236 passing tests in 34 files and successful production build. |
| npm-audit.json | Approved fresh dependency-only request to the public npm registry: zero production advisories. Scope is dashboard npm dependencies only. |
| recovery-current-verified.txt | 93 passing restore-flow assertions with fake Docker/database operations. Includes R6 failure/retry cases. Native Unix permission checks skip on the Windows filesystem. |
| secret-scan.txt / Scan-Secrets.ps1 | Tracked-text marker and filename scan, without printing candidate values. Two benign private-key delimiters were examined. Not full-history, entropy or untracked-secret coverage. |
| resolved-backend-versions.txt | Selected resolved JAR versions extracted from the Maven/Surefire classpath. This is an inventory, not a complete vulnerability scan. |
| baseline.txt / source-manifest.tsv | Final audited source and working-tree baseline; SHA-256 hashes cover copied application/configuration inputs. |
| reviewed-documents.tsv | Hashes for the concurrently updated launch-signoff/runbook documents, captured separately from application/configuration inputs. |
| environment.txt | Local tool versions and explicit deployment-validation limits. |

## Reproduction

Use a disposable copy, the provided source manifest and the correct dependency lockfiles. Fixtures contain only synthetic tokens, keys and accounts. They are not installed in the live application's test folders.

Backend tools: JDK 17.0.19 and Maven 3.9.15, cached local Maven repository. Copy `SecurityRevocationAuditTest.java` to `src/test/java/com/aiwa/service/impl/` and `SecurityTotpAuditApiTest.java` to `src/test/java/com/aiwa/api/` in the disposable backend. Run:

```text
mvn -B -o -Dtest=SecurityRevocationAuditTest,SecurityTotpAuditApiTest test
```

The final targeted security run selects these fixtures plus AdminReadExportRbacApiTest, AdminRefreshCookieApiTest, AdminTwoFactorApiTest, HardeningApiTest, ModerationPrivacyApiTest, TempPasswordSessionApiTest, VerifiedEmailApiTest, ProductionGuardConfigTest, JwtAuthFilterTest, JwtUtilsTokenTypeTest, RedisRateLimitFilterTest, AccountRateLimiterTest, FileStorageDecodeLimitsTest, FileStorageMetadataTest, FileStorageServiceImplTest, OtpPumpingGuardTest, OtpRedisDownTest, TokenBlacklistServiceTest, PrivateFileCipherTest and TotpSecretConverterTest.

After that run, five live moderation source/test files had changed. They were reviewed, copied into the snapshot and checked with:

```text
mvn -B -o -DforkCount=0 -Dtest=AdminReadExportRbacApiTest,ModerationPrivacyApiTest,AdminQueueQueryCountTest test
```

That latest-source run covers query changes and authorization/privacy regressions. The unchanged security/authentication sources retain the 114-test evidence; it is not mislabeled as a complete backend suite.

The final run used `MAVEN_OPTS=-Xmx256m -XX:MaxMetaspaceSize=192m -XX:ReservedCodeCacheSize=32m -XX:+UseSerialGC -XX:ActiveProcessorCount=2` to avoid allocating a second JVM on the memory-constrained host. Do not interpret the two retained resource failures as passing runs.

Flutter tools: installed Flutter 3.47.5 / Dart 3.13.4 and `PUB_CACHE=D:/tools/pubcache`. Copy the audit Dart fixture into disposable `test/`, then run:

```text
flutter analyze --no-pub
flutter test --no-pub --reporter expanded --timeout 30s test/security_request_owner_audit_test.dart test/core/session_event_ownership_test.dart test/core/api_client_session_test.dart test/core/api_client_refresh_session_test.dart test/blocs/auth_attempt_race_test.dart
```

The unbounded whole-suite attempt is recorded separately and is not claimed successful. The timeout above bounds individual test bodies, not every tool-startup/teardown condition.

Dashboard tools: Node 20.20.2, clean dependencies installed in the disposable copy from the lockfile. Commands:

```text
npm test -- --reporter=dot
npm run build
npm audit --omit=dev --audit-level=high --json --registry=https://registry.npmjs.org
```

Recovery: run `bash restore_flow_test.sh` from disposable `deploy/`. On this Windows host, Git Bash needed `PATH=/usr/bin:/bin:$PATH` and a POSIX-form `TMPDIR` under audit staging. Initial attempts had environment/path/sandbox errors; the recorded final 93-pass run used the working configuration. No live restore/backup or Docker database was invoked.

## Dependency review

Official pages were checked on 6 October 2026: [Apache Tomcat security](https://tomcat.apache.org/security-10.html), [JJWT support policy](https://github.com/jwtk/jjwt/security), [Spring's DPoP advisory](https://spring.io/security/cve-2026-41707/), and [Redis persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/). The report distinguishes affected-version matches from application feature reachability. The npm result is not a backend/Dart/image/OS clearance.
