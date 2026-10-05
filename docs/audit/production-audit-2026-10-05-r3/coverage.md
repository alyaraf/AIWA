# Audit coverage and validation

Date:2026-10-05. Baseline:`ac67446495a22ce11b8f2071d0f1599f3c0cdee4`. Repository:`D:\AIWA PROJECT\AIWA`. Audit stage:`C:\Users\fsherif\.codex\visualizations\2026\10\05\01a10bf7-f91b-7363-9de4-71d88794cf43\audit-work`. No application code modifications or dependency upgrades. Testing generated outputs only in an isolated copy. Documentation delivery is authorized by the request.

## Systematic coverage checklist

| Area | Static audit coverage | Runtime evidence / remaining boundary |
| --- | --- | --- |
| Repository/handoff/history | Root structure, HANDOFF.md, relevant prior audits/fix status, current config/docs, baseline and concurrent18-file commit | Clean current baseline confirmed; complete Git-history/ignored-secret-value scan not performed |
| Backend controllers/security | All29 controllers/181 handlers, request/response DTOs, URL/method/MFA filters, authentication and resource-owner helpers |411 existing tests plus six synthetic controller/service probes; no live production traffic |
| Backend services/repositories/entities |202 main Java files include controller/config/security/service/repository/entity/enum/utility/i18n/migration code; booking, money, privacy, ownership, file, provider and job flows prioritized | Existing service/API/JPA tests pass; PostgreSQL lock/query/load/actual external gateway behavior not reproduced in this pass |
| Database |32 SQL migrations plus JavaV19, entity relationships, repository queries/locks, uniqueness/index/cascade/version and financial snapshots | Actual deployed migration history/data volume, EXPLAIN and legacy constraint validation not verified |
| Flutter |176 lib Dart files: boot/DI/constants/network/storage/router/push/telemetry/theme/l10n/shared UI plus auth/onboarding/discovery/providers/bookings/chat/reviews/profile/notifications/provider dashboard features | Analyzer clean;178 tests pass. Generated localization reviewed as generated interface, not hand-authored business code |
| Mobile tests/platform |33 Dart test files plus golden assets (54 test-directory files total), one integration-test source; Android manifests/Gradle/signing/network and iOS plist/entitlements/privacy/build configs | Host widgets/goldens pass. Integration_test device execution, signed AAB/iOS archive/store review/OS permissions not run |
| Admin | App.jsx, api.js, main.jsx, CSS,20 test files/setup (25 src files), index, Vite/Vitest, manifest/lock/Docker/nginx/environment |120tests/build/npm audit pass; source/micro reproductions. No new cookie-bearing browser/device/assistive technology run here |
| Infra/CI | Main and legacy compose, Dockerfiles, Caddy/nginx, env templates/secret locations, backup/offsite/restore/tests, monitoring/exporters/rules/receivers, public site, load/smoke scripts and workflows |31 backup harness checks pass; .env pass-through fixture verified. No live containers/restore/load/GitHub job/cloud/alert delivery evidence |
| Integrations/error/logging | SMS/email/FCM/Sentry adapters, retries/OTP/session/notification budgets, error mapping and redaction formats | Provider sandbox/deliverability, deployed Sentry/alerts and log retention/access unverified |
| Dependencies | Maven manifests/resolution, npm lock/advisories, Dart manifests/lock/imports and native integration configuration | npm0advisories; no backend NVD-key scan or comprehensive mobile/native/SBOM/license scan |

The accompanying `source-manifest.tsv` lists material tracked source/config/test/document paths, sizes and SHA256 at delivery. It is an inventory/integrity aid, not an assertion that a hash proves review quality or runtime correctness. Generated build output, dependency caches, binary fonts/images/archives and ignored credential values are outside semantic source review; layouts are partially verified by existing goldens. Old reports are historical context, not current defect evidence.

## Executed validation

| Command / harness | Runtime | Result |
| --- | --- | --- |
| `mvn.cmd -B -o -Dmaven.repo.local=C:\Users\fsherif\.m2\repository test` | JDK17.0.19.10, isolated current backend snapshot |411tests,0failures,0errors,0skipped; BUILD SUCCESS |
| Node20.20.2 existing Vitest `run`, existing Vite build, npm audit JSON | Isolated dashboard with copied installed dependencies and unchanged lockfile |20test files/120tests pass; Vite1573modules/build success;0reported vulnerabilities |
| `D:\tools\flutter\bin\flutter.bat analyze --no-pub` | Flutter3.47.5/Dart3.13.4, PUB_CACHE=`D:\tools\pubcache`, isolated app |No issues found |
| `D:\tools\flutter\bin\flutter.bat test --no-pub` | Same Flutter host environment |178pass; English/Arabic golden screenshots included |
| Git Bash `bash ./deploy/backup/backup_test.sh` | Snapshot; fake Docker; explicit /usr/bin:/bin PATH; isolated TMPDIR |31pass,0fail; one NTFS-mode assertion reported skip |
| Synthetic Spring/H2 probe, JDK17 `-Xmx192m` | In-memory H2/test profile/random local port/dev-log providers |Review lazy-serialization and unsave transaction exceptions; pending customer contacts/home location; mutable destination; ADMIN-without-SUPPORT SOS read |
| Synthetic JDK PNG probe, `-Xmx128m` |66-byte generated fixture,20,000,000×1RGBA header, same subsampling |IIOException caused by OutOfMemoryError in PNGImageReader.decodePass |
| Exact-function admin micro checks | Safe synthetic CSV/async policy/idle export/page fixtures |Formula emitted; delayed policy overwrote wrong type; idle export still sent bearer;50-page cap silently truncated51pages |
| Compose `.env` bare-variable fixture | Disposable configuration only |Bare allowlisted variables receive project .env values; earlier suspected missing environment pass-through is not a finding |

Tests were run sequentially across JVM and Node/Flutter to avoid the documented small Windows paging-file/resource issue. Default machine Java8 and Node12 were not used. Flutter SDK/dependency cache and Maven/npm path access required sandbox escalation; this did not authorize or perform source remediation. The first backend snapshot omitted alerts.yml and produced one fixture error; copied current monitoring fixture and current source then passed the complete suite. Environment failures are separated from code failures.

## Verification evidence

[validation/README.md](validation/README.md) indexes saved summaries/logs. Backend suite evidence intentionally preserves result lines rather than dumping arbitrary test log payloads. Probe contacts/locations are synthetic `audit.invalid` fixtures, not real users. No deployment secrets are included.

Not executed: real PostgreSQL/Redis concurrent workload and migration rehearsal in this pass; remote GitHub Actions/NVD/image scans; k6/soak; staging compose startup/rollback; live/offsite restore; cloud IAM/key custody/bucket lifecycle; gateway SMS/email/FCM sandbox sends; Android/iOS hardware or release archives; new admin browser/CSP/cookie scheduling and accessibility run; whole Git-history/compiled artifact secret scan. Each is represented as NOT VERIFIED or a specific runtime follow-up in the report, rather than assumed to pass.
