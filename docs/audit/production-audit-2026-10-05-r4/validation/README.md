# Fresh validation evidence — round 4

Audited commit 290a05f0606545c073c22e1753cc9ad5c584fa5a, 2026-10-05, isolated synthetic audit copy.

| File | Evidence |
| --- | --- |
| backend-tests.txt | 483 tests; zero failures/errors/skips; BUILD SUCCESS |
| backend-probes.txt | SOS mapper uses edited address while booking snapshot remains frozen |
| admin-tests.txt | 164 tests / 28 files pass |
| admin-build.txt | Production Vite build succeeds |
| admin-advisories-public.json | Public npm production advisory scan reports zero vulnerabilities |
| admin-advisories.json | Configured corporate-registry audit failed; not a vulnerability result |
| admin-probes.txt | Late private blob and cross-tab retained restricted SOS reproduced |
| sos-probes.txt | Older initial empty SOS response overwrites newer successful poll and claims live |
| flutter-analyze.txt | Final analyzer: no issues found |
| flutter-tests.txt | 221 existing tests pass |
| flutter-probes.txt | Old startup cleanup deletes newer session; obsolete login failure overwrites auth state |
| shell-checks.txt | 32 backup, 33 swap, 23 restore-flow checks; separate failed OS rollback reproduction |
| restore-outer-probes.txt | Six added assertions confirm restart after failed file rollback and plaintext retained safety dump; original 23 checks also pass |
| probe-fixtures.md | Audit fixture source for reproducibility; synthetic identities/data only |

“Passing” audit reproductions means they verified the defective current behavior. These are distinct from green regression tests proving fixes. Maven/Vitest/Flutter suite counts exclude the extra audit probes.

No live infrastructure, production user, external message or actual cloud/volume restore was exercised. Real-container, PostgreSQL, browser, device, provider and cloud validation remains pending as stated in the report.
