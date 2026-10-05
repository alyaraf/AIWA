# Verification evidence

> After remediation: [remediation-results.md](remediation-results.md). The files below are the audit-time baseline.

Audit baseline:`ac67446495a22ce11b8f2071d0f1599f3c0cdee4`,2026-10-05. Tests ran on an isolated snapshot; all probe data is synthetic. No deployed service or live data was attacked/restored.

- [Backend test result lines](backend-tests.txt):411tests,0failures/errors/skips.
- [Admin tests](admin-tests.txt):120tests/20files pass; jsdom scrollTo warnings are harness limitations.
- [Admin production build](admin-build.txt): successful Vite output and observed sizes.
- [Admin dependency advisory scan](admin-dependency-audit.json): npm reports0vulnerabilities at audit time.
- [Flutter analysis](mobile-analyze.txt): no issues found.
- [Flutter test summary](mobile-tests.txt):178pass including English/Arabic goldens.
- [Backup/restore harness](backup-tests.txt):31pass; NTFS permission-mode assertion skip is explicitly reported.
- [Synthetic backend fixture results](backend-probes.txt): six privacy/persistence/model/permission reproductions.
- [Bounded image decoder](png-probe.txt): expected isolated OutOfMemoryError wrapped by ImageIO; not a test-suite failure.

For exact toolchain and command context, see [coverage.md](../coverage.md). Runtime caveats remain in each issue card. These logs do not establish production load capacity, OS-device behavior, provider deliverability, remote retention/key escrow or successful offsite disaster recovery.
