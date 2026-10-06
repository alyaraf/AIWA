# Round 3 findings rechecked against 290a05f — round 4

Date: 2026-10-05. Project: D:/AIWA PROJECT/AIWA. This table supersedes the closure claims in the round 3 remediation record. The old report is retained as history.

**Fixed** means the originally identified defect is closed in reviewed source with the stated available evidence. It does not mean device, provider, cloud, PostgreSQL or production validation ran. **Partial** means a material path in the original scope remains defective. **Mitigated** means impact/visibility/retry improved while the full guarantee remains incomplete. **External** requires operator configuration/evidence.

Summary: **29 Fixed, 5 Partial, 3 Mitigated, 1 External = 38**. These are previous-finding statuses; eight current R4 cards are counted separately and overlap some of the partial findings.

| Previous ID | Status | Fresh assessment / evidence | Remaining work |
| --- | --- | --- | --- |
| B-01 | Fixed | Pre-decode side and working-memory bounds; FileStorageDecodeLimitsTest passes | Bounded-heap/concurrent staging measurements |
| B-02 | Fixed | Shared home-location state policy; privacy projection tests pass | Product policy acceptance/deployed masking matrix |
| B-03 | Fixed | Provider dashboard uses shared live-state contact projection; tests pass | Staging permission/state matrix |
| B-04 | Fixed | SUPPORT reads and capability-filtered inbox; read/export RBAC tests pass | Enrolled-MFA staging matrix; client isolation separately R4-03 |
| B-05 | Partial | New bookings/admin booking DTOs snapshot destinations; V34/amend tests pass | SOS projection still live: R4-02; mobile amendment UI absent; V34 rehearsal |
| B-06 | Fixed | Review tags copied within transaction; OSIV-off boundary test passes | Production query count/serialization smoke |
| B-07 | Fixed | Unsave transaction plus repository transaction; repeated deletion tested | PostgreSQL smoke |
| B-08 | Fixed | Single rejected-FCM outcome increment; test passes | Provider/runtime metrics |
| M-01 | Partial | Old profile successes/cache writes guarded; existing session tests pass | Startup deletion and obsolete login failures reproduced: R4-05 |
| M-02 | Fixed | Server live-status query and continuation retained; tests pass | Device pagination |
| M-03 | Fixed | Multipart retry clones FormData; real file test passes | Expired-token device upload |
| M-04 | Fixed | Transient profile failure keeps identity; only rejected session drops it | Remaining auth-operation race is R4-05 |
| M-05 | Mitigated | Server stage + existing-profile/staff retry and pending actions tested | Durable staff/input recovery after process death remains incomplete |
| M-06 | Fixed | Narrow travel-buffer PATCH; stale whole profile is not posted | Backend/mobile compatibility rollout |
| M-07 | Fixed | Full role policy, version pinned and acceptance checked; tests pass | Failed newer-policy reload UX; wording/device review |
| M-08 | Fixed | Deferred booking consumed at the step that ends on Home; tests pass | Device full signup |
| M-09 | Fixed | Local-launch payload enters pending route pipeline; positive IDs enforced | Terminated Android/iOS tap evidence |
| M-10 | Fixed | Query/page generations and continuation handling tested | Real slow-network walkthrough |
| M-11 | Fixed | Page advances after success, dedupe/single continuation/retry tested | Device paging |
| AD-01 | Fixed | Client/server formula neutralization incl. leading controls; tests pass | Open export in a spreadsheet |
| AD-02 | Fixed | Terms draft associated with requested type; stale load/publish guards tested | Staging policy publish |
| AD-03 | Fixed | Remaining payout balance remains actionable; refreshed balance test passes | Finance staging smoke |
| AD-04 | Partial | Idle signal/timer and shared authenticated transport tested | Loaded old-account views and delayed blobs remain: R4-03/04 |
| AD-05 | Partial | Failed/hung/offline polls visibly stale; existing eight tests pass | Initial/manual stream can erase newer SOS and claim live: R4-07 |
| AD-06 | Fixed | Global refresh waits for subscribed loaders; smoke/detail tests pass | Real API loader/error behavior |
| AD-07 | Fixed | Partial warn/suspend + close retains retry-only state; tests pass | Real write failure smoke |
| AD-08 | Fixed | Named capabilities drive nav and admin target actions; tests pass | Route/cache reset remains R4-03 |
| AD-09 | Fixed | Hidden DTO state retained, displayed and restorable; tests pass | Deployed DTO smoke |
| AD-10 | Fixed | Settlement detail clears old load error; test passes | — |
| AD-11 | Fixed | Shared named modal, focus/Escape/inert primitives and keyboard rows; tests pass | Native browser/screen reader; nested modal behavior |
| AD-12 | Fixed | Public support email copy now names actual channels | Delivered SOS/on-call/provider evidence |
| AD-13 | Mitigated | Cap/truncation notice tested; silent cap addressed | Server paging/search and complete totals/worklists still needed |
| I-01 | Fixed | Filesystem selectors and host absence rule corrected; rule tests authored | promtool and delivered alert not executed here |
| I-02 | Partial | Pre-extraction/safety-copy/forward-failure rollback tested | OS rollback errors still unsafe: R4-01 |
| I-03 | Mitigated | Dump-first contract, manifest and reference report added | Atomic/coherent snapshot not established; concurrent writer drill |
| I-04 | Fixed | Development compose exposes DB/Redis only on loopback; docs corrected | Operational use of production compose |
| I-05 | External | Retention/immutability/IAM/escrow policy documented | Actual bucket/key evidence and offsite-only restore |
| I-06 | Fixed | Opaque identity and provider-message scrubbing tested | Runtime logs/retention/access; safety dump separately R4-06 |

Potential risks were also rechecked:

| ID | Current assessment |
| --- | --- |
| P-01 | prod+local/test rejected by unconditional guard; unit tests pass. Inspect resolved staging profiles |
| P-02 | HTTPS/public literal host/no userinfo/optional allowlist rules tested. DNS/egress and real endpoints remain operational |
| P-03 | Same-tab login waits for signout; test passes. Cross-tab/native-cookie ordering remains a browser gate |
| P-04 | JSON late success guarded; incomplete for blobs/already-loaded views: R4-03/04 |
| P-05 | Docker build forces mocks off and checks HTTPS; actual release container/artifact unverified |
| P-06 | Effective token cutoff includes temporary-password expiry; tests pass. Forced-change UI remains a product decision |
| P-07 | Generic 2xx refusal parsed for email/SMS; gateway tests pass. Exact provider acceptance/delivery remains unverified |
| P-08 | Deployment secrets/IAM/history/artifact controls require operator evidence; no production configuration certification |

New R4 findings: R4-01 recovery rollback; R4-02 SOS destination; R4-03 cross-tab retained restricted data; R4-04 late blob; R4-05 mobile stale auth operations; R4-06 plaintext retained safety backup; R4-07 SOS ordering/freshness; R4-08 staging check dependencies. See [audit.md](audit.md) for severity, absolute source links, reproductions and fixes.
