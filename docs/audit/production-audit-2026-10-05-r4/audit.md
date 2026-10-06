# AIWA production audit — round 4

Date: 2026-10-05. Project: D:/AIWA PROJECT/AIWA. Branch: main. Audited commit: 290a05f0606545c073c22e1753cc9ad5c584fa5a. The working tree was clean at the beginning and remained clean through application validation. This report supersedes the round 3 remediation's closure claims; the historical reports remain unchanged.

## 1. Executive Summary

**Production decision: do not launch yet.** The update substantially improves privacy, permissions, booking integrity, client retry behavior and recovery tooling. Nevertheless, eight actionable findings remain in the reviewed release: **3 High, 4 Medium, 1 Low**. Seven have deterministic audit reproductions; the CI dependency finding is confirmed directly from the workflow.

The most consequential gaps are a restore that restarts the backend after failed filesystem rollback, an SOS response that uses an edited address instead of the agreed booking destination, and a cross-tab account change that leaves restricted data visible to the new admin. The new tests are valuable, but they do not exercise these paths.

The 38 previous findings are reconciled individually in [remediation-status.md](remediation-status.md): **29 closed in the reviewed code paths, 5 partially fixed, 3 mitigated, 1 dependent on external configuration**. Closure means the identified source defect is addressed and its available evidence passes; it does not certify a deployed production system. M-05 remains mitigated because server onboarding stages do not durably preserve every partially completed input.

| Fresh validation | Result | Limit |
| --- | --- | --- |
| Backend, JDK 17, offline Maven | 483 tests; zero failures, errors or skips | H2/test dependencies; no PostgreSQL service |
| Dashboard, Node 20.20.2 | 164 tests / 28 files; production build passes | Vitest/jsdom, no fresh browser or deployed API |
| Production dashboard dependency audit | 0 reported vulnerabilities | Public npm advisory database at audit time |
| Flutter 3.47.5 / Dart 3.13.4 | Analyzer clean; 221 tests pass | Host tests and goldens, no device/release archive |
| Backup / staged uploads / restore-flow harnesses | 32 / 33 / 23 checks pass | Fake Docker and disposable directories |
| Additional audit reproductions | Backend mapper 1; dashboard 3; mobile 2; rollback/outer restore checks pass | Assertions deliberately verify defective behavior; they are not regression fixes |

Docker Desktop's Linux engine pipe is absent. Real PostgreSQL/Redis, promtool, container recovery, CI execution, provider delivery, offsite storage, device behavior and load remain unverified. The 34 launch-signoff gates still have no completed evidence recorded. [Coverage and commands](coverage.md), [validation evidence](validation/README.md), [183-handler API inventory](api-inventory.md) and [end-to-end flows](api-flows.md) document the boundary.

No application source, tests, dependencies, database migrations or deployment settings were changed in the project. Audit probes and builds ran in an isolated copy; only this documentation and HANDOFF.md are delivered.

## 2. System Architecture

| Component | Absolute location | Responsibility |
| --- | --- | --- |
| Mobile | D:/AIWA PROJECT/AIWA/Android/aiwa_app | Flutter feature data/domain/presentation layers, Bloc, GetIt, Dio and go_router; customer/provider shells, secure storage, Arabic/English UI, discovery, booking and provider management |
| Backend | D:/AIWA PROJECT/AIWA/aiwa-backend | Java 17, Spring Boot 3.5.16, Spring Security, MVC, JPA, Flyway, typed DTOs, centralized errors/i18n, jobs and integration adapters |
| Dashboard | D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated | React 18.3.1 / Vite 6.4.3; capability-sensitive navigation, API adapter, paginated queue collection, exports and polling |
| Persistence | Backend entity/repository/migration packages | PostgreSQL 16; 28 entity files, 26 repository files, 33 SQL migrations plus Java V19; money/destination snapshots, versions, unique constraints and selected locks |
| Ephemeral state | Redis deployment and RedisRuntimeService | OTP/rate budgets, cache, revocation acceleration and distributed job locks with selected fallback paths |
| Storage | Backend storage service and uploads volume | Normalized public images; authorized encrypted identity documents; database file references |
| Operations | D:/AIWA PROJECT/AIWA/deploy and .github/workflows | Caddy TLS/proxy, nginx admin, resource-limited backend, PostgreSQL/Redis volumes, backup/offsite services, Prometheus alerts, CI and runbooks |
| Integrations | Backend adapters / mobile push and Sentry configuration | SMS/email HTTP gateways, Firebase FCM, on-call delivery, device notifications and crash reporting |

Mobile requests follow page → Bloc/repository → Dio/session handling → JWT and rate filters → controller validation → service ownership/state/transaction → PostgreSQL/Redis/files/notifications → audience-specific DTO → client state/UI. Admin requests follow React loader → API session adapter → the same backend gates → service/DTO → queue/detail UI.

Accounts are CUSTOMER, PROVIDER and ADMIN. Admin capabilities are SUPPORT, FINANCE and SUPER_ADMIN; super-admin receives the effective support/finance powers. Resource participation and ownership remain service responsibilities. Payments use cash confirmations and an internal commission ledger; no card acquiring integration or stock workflow exists in the inspected project.

The deployment is a single-host design. Only the edge publishes application ports in the production stack. Isolation, dropped capabilities, read-only filesystems and bounded resources are strengths, but they do not establish high availability or capacity for thousands of concurrent users.

## 3. Critical Issues

No Critical-severity defect was established in this pass. No production exploitation, actual file loss or live provider delivery failure was exercised. The following High findings are launch blockers based on reproducible code behavior.

## 4. High Priority Issues

### R4-01 — Filesystem rollback errors are ignored, and restore restarts an inconsistent system

- **Severity/category:** High — recovery correctness / data integrity. **Evidence:** CONFIRMED, reproduced with OS-command fault injection and the outer fake-Docker restore flow. Related: I-02.
- **Files/functions:** [uploads_swap.sh](<D:/AIWA PROJECT/AIWA/deploy/backup/uploads_swap.sh:75>), rollback_swap and rollback case (lines 79, 82, 115–119); [restore.sh](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:105>), failed swap recovery (lines 105–112).
- **Issue:** Forward moves are checked, but rollback uses unchecked plain mv calls. The script assumes removing its own failure hook makes rollback infallible. Real rename failures still affect rollback. The journal is deleted even when the old files have not returned. The explicit rollback command can print success and exit zero after those failures.
- **Danger:** restore.sh interprets any failed swap as successfully restored old uploads. If the database rollback succeeds, it restarts the backend and claims both stores are back. Database references may then point to absent live files. The retained files can remain recoverable under .restore-previous, but the active pair is inconsistent.
- **Reproduce:** In a disposable uploads tree, stage a tarball; wrap mv to reject both staged/public → live/public and previous/public → live/public. The swap fails, old public files remain only under previous, and manual rollback returns zero. In the outer fake-Docker probe, database rollback succeeds and start backend is recorded despite the absent old avatar. Existing UPLOADS_SWAP_FAIL_AFTER tests only fail forward mv_one and deliberately bypass that hook on rollback.
- **Recommended fix:** Return and propagate a distinct rollback-failed state, check every recovery rename, retain the recovery journal and staging/previous trees until success, verify the expected live tree, and keep the backend stopped unless both database and files are confirmed restored. Add actual rollback-command failures to tests and rehearse with real volumes.
- **Evidence:** [shell checks](validation/shell-checks.txt), [outer restore reproduction](validation/restore-outer-probes.txt).

### R4-02 — SOS queue uses the mutable saved address instead of the booking destination

- **Severity/category:** High — safety / business data integrity. **Evidence:** CONFIRMED, synthetic backend mapper reproduction. Related: B-05.
- **File/function:** [SafetyService.java](<D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/service/impl/SafetyService.java:531>), toAdminDto, especially lines 540–541; used by adminQueue and resolve.
- **Issue:** Normal booking and admin-booking DTOs now use BookingPrivacy.destinationOf. The SOS DTO still reads b.getSavedAddress().getAddressLine(). Editing an address after booking leaves the visit snapshot unchanged but changes the location shown to support.
- **Danger:** An operator handling an emergency can read a street address unrelated to the agreed visit. GPS fields are optional and do not repair the textual address; this is particularly serious without a usable location fix.
- **Reproduce:** Snapshot “Agreed home A” into a home booking; change the saved address to “Edited unrelated home B”; map a linked SOS. The booking projection returns A, while the admin SOS projection returns B.
- **Recommended fix:** Use the same immutable destination projection in every safety/admin delivery projection that represents a booking visit. Preserve reported live GPS as a distinct field. Add an SOS end-to-end test after saved-address editing and V34 backfill coverage.
- **Evidence:** [backend probe](validation/backend-probes.txt).

### R4-03 — Cross-tab account changes retain the previous admin's restricted view

- **Severity/category:** High — client privacy / session isolation. **Evidence:** CONFIRMED, rendered React reproduction. Related: AD-04 / P-04.
- **File/function:** [App.jsx](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src/App.jsx:500>), App storage listener, profile hydration and route rendering (lines 489–507, 563–576).
- **Issue:** A nonempty session hint from another tab triggers a profile refresh without dropping the old session, route or mounted page. When the new profile arrives, navigation permissions update, but the existing page's loaded private data remains mounted. Route rendering has no corresponding capability guard or identity-keyed reset.
- **Danger:** A lower-capability account using the same browser can see private rows loaded under a previous account, even though its navigation entry is hidden and the backend would refuse a fresh request. This demonstrates retained client data, not a new backend permission bypass.
- **Reproduce:** Load an SOS row as a super/support admin. Simulate another tab signing in as Finance B via the session storage event and return B from /auth/me. The sidebar displays “Admin · Finance B”, Safety navigation disappears, and the previous SOS notes remain visible.
- **Recommended fix:** On a changed session hint, immediately clear sensitive views and permission state; hydrate the new identity before mounting protected pages; reset or key the entire authenticated subtree by identity/session generation; enforce capability checks when rendering routes. Test changed-account events, hydration failure and already-loaded details.
- **Evidence:** [dashboard probes](validation/admin-probes.txt).

## 5. Medium Priority Issues

### R4-04 — Private blob bodies escape the session-generation check

- **Severity/category:** Medium — client privacy / asynchronous session isolation. **Evidence:** CONFIRMED, deterministic deferred-body reproduction. Related: AD-04 / P-04.
- **File/function:** [api.js](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src/api.js:255>), authedBlobFetch; verificationDocUrl at line 434; downloadFile at line 636.
- **Issue:** The generation check runs after fetch resolves headers. Document/export helpers subsequently await response.blob without checking the generation again. The normal JSON transport correctly waits for the body before its check.
- **Danger:** A private document object URL or export download can complete after logout/account change. Component unmount guards mitigate a currently closed document modal, but do not make the helper safe, prevent an export side effect, or solve R4-03.
- **Reproduce:** Resolve a document's headers under A; delay blob(); start B's session; finish the body. verificationDocUrl returns an object URL for A's document instead of SESSION_CHANGED.
- **Recommended fix:** Capture the generation and validate it after complete body consumption and immediately before URL/download side effects. Apply one session-aware body helper to JSON, blobs and streamed exports; cancel obsolete requests where practical.
- **Evidence:** [dashboard probes](validation/admin-probes.txt).

### R4-05 — Old mobile auth handlers can remove a newer session or authenticated state

- **Severity/category:** Medium — mobile session availability / state races. **Evidence:** CONFIRMED, two deterministic Bloc/storage reproductions. Related: M-01.
- **Files/functions:** [auth_bloc.dart](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/features/auth/presentation/bloc/auth_bloc.dart:117>), _onCheckSession and _onLogin; _safe and registration/OTP branches need equivalent review. [auth_repository_impl.dart](<D:/AIWA PROJECT/AIWA/Android/aiwa_app/lib/features/auth/data/repositories/auth_repository_impl.dart:18>), login exception conversion.
- **Issue:** Generation guards protect profile success, but the remember=false startup branch clears storage without a guard after its awaits. Login's failure fold also emits unconditionally. SessionChangedException subclasses NetworkException, so login converts a discarded old response into an ordinary failure that the shared Bloc publishes.
- **Danger:** A delayed cold-start check can clear B's freshly stored tokens and sign B out; an obsolete A login failure can replace AuthAuthenticated(B) with AuthError while B's credentials still remain stored. These reproductions establish state/session loss, not exposure of A's profile.
- **Reproduce A:** Hold getRemember(); complete a B login/profile; return false from the old startup check. B's access token becomes null and state becomes AuthUnauthenticated.
- **Reproduce B:** Hold A's login; complete B's login/profile; finish A with the transport's SessionChangedException. State becomes AuthError while B's access token remains.
- **Recommended fix:** Define a generation/attempt token for the complete auth operation, including failures, startup cleanup, server revocation, cache/storage writes and generic catches. Ignore obsolete outcomes before destructive operations. Serialize or explicitly cancel incompatible auth attempts; retain SessionChangedFailure semantics throughout repositories.
- **Evidence:** [mobile probes](validation/flutter-probes.txt). The existing M-01 profile tests still pass.

### R4-06 — Restore retains an unencrypted safety dump outside backup retention

- **Severity/category:** Medium — sensitive-data retention / disk capacity. **Evidence:** CONFIRMED from source and fake-Docker safety-dump reproduction.
- **Files/functions:** [restore.sh](<D:/AIWA PROJECT/AIWA/deploy/restore.sh:86>), safety-copy creation; [backup.sh](<D:/AIWA PROJECT/AIWA/deploy/backup/backup.sh:119>), retention; offsite.sh enumerates normal db/uploads backups.
- **Issue:** Each restore permanently writes backups/pre-restore-*.dump as plaintext, even when normal backups are encrypted. The temporary-decryption cleanup trap does not include it. Scheduled retention covers db, uploads and manifest subdirectories, not these files at the backups root.
- **Danger:** The complete pre-restore database accumulates under a weaker at-rest policy and can fill the host. umask 077 correctly limits local permissions, so this is not public file exposure, but it does not provide the normal backup encryption/retention guarantee.
- **Reproduce:** Run the fake successful/failed restore flow; read the retained pre-restore dump directly without a key. Compare its root location with the scheduled find/prune directories.
- **Recommended fix:** Encrypt and verify retained safety copies under the normal backup policy; make their retention and rollback key requirements explicit; budget their disk space and clean partial artifacts after interrupted runs. Preserve the rollback copy until verified recovery succeeds.
- **Evidence:** [outer restore reproduction](validation/restore-outer-probes.txt).

### R4-07 — Initial/manual SOS loads can overwrite a newer poll and reset “Live”

- **Severity/category:** Medium — incident-monitoring correctness / state ordering. **Evidence:** CONFIRMED, fake-timer React reproduction. Related: AD-05.
- **File/function:** [App.jsx](<D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src/App.jsx:3705>), SafetyQueue / useLoad; confirmation effect lines 3714–3716 and independent poll generation.
- **Issue:** Polls have a sequence guard, but initial/manual useLoad requests use a separate stream. An older load can replace a newer poll's data. The confirmation effect treats every nonloading/error-free data change, including local changes, as a fresh server confirmation.
- **Danger:** A new SOS already observed by a poll can disappear when an older empty response arrives; the UI then displays “No open SOS alerts” and “Live”. A later successful poll may recover it, but a subsequent failure or delay extends the missed interval.
- **Reproduce:** Delay the initial request after it observes an empty queue. At 15 seconds return NEW_SOS from the periodic poll. Then complete the initial request with []. The page renders the empty/live claim and the new row is absent.
- **Recommended fix:** Use one request-generation/order policy for initial, manual, badge-triggered and timed loads. Record freshness only on an accepted server read; never infer it from local mutations. Apply timeouts/stale visibility consistently to initial/manual loads as well.
- **Evidence:** [SOS probe](validation/sos-probes.txt). The eight existing stale/offline tests still pass.

## 6. Low Priority Issues

### R4-08 — Staging deployment does not wait for the newly added recovery and monitoring checks

- **Severity/category:** Low — CI / release assurance. **Evidence:** CONFIRMED workflow dependency.
- **File/job:** [ci.yml](<D:/AIWA PROJECT/AIWA/.github/workflows/ci.yml:259>), deploy-staging needs at line 260; monitoring-rules, backup-restore, Flutter, Android, SBOM and dependency-scan jobs.
- **Issue:** The new jobs run, but deploy-staging still needs only backend and admin. A staging deployment can start while recovery/monitoring/mobile checks are failing or running. This is a staging workflow gap; no automated production deployment was established.
- **Danger:** An operator can treat a deployed staging revision as fully validated when its operational checks have not passed, weakening rehearsal and release evidence.
- **Reproduce:** Inspect the job dependency graph: fail backup-restore or monitoring-rules while backend/admin pass and staging variables are configured. The deploy job remains eligible.
- **Recommended fix:** Define an explicit required-release gate and make deployment/promotion depend on the checks appropriate to that environment. Include skipped vulnerability scans in the reported status and verify branch/environment protection. Keep SBOM generation distinct from vulnerability scanning.

## 7. Mobile App Findings

The updated profile transport, cache generation checks, multipart cloning, status-filtered Upcoming list, booking-query/notification paging, narrow travel-buffer mutation, deferred booking and local-notification launch parsing address their original specific defects. Terms consent now displays the full role policy and checks the shown version before acceptance.

R4-05 shows that the shared auth Bloc is still inconsistent across async branches. A broad try/catch is insufficient without attempt ownership. First-page, continuation and session boundaries must compose; passing profile-race tests does not cover login failures or startup deletion.

Provider onboarding now returns NO_PROFILE / NEEDS_DOCUMENTS / SUBMITTED based on server data and can reuse an existing profile/deduplicate staff during retry. This removes the old permanent “profile already exists” trap. However, the Preferences page's completed-step index and desired staff/document inputs remain in memory. If the process dies after profile commit but before staff completion, the resumed NEEDS_DOCUMENTS path does not reconstruct every unfinished staff input. Treat M-05 as mitigated pending durable checkpoint behavior and device kill/relaunch evidence.

The destination-amendment API has no mobile caller/screen. Existing home visits remain frozen; users currently need an agreed product flow for changing a visit destination. Also verify a terms-changed reload that fails: TermsPage retains _doc, so the old policy can remain visible while the latest-version check prevents final acceptance. This is a source-level UX follow-up, not evidence of recording the wrong consent.

Navigation/deep links, permission priming, shared notification state, cold launch, RTL/goldens, keyboard and device sizing were reviewed against prior findings and new tests. No physical-device, screen-reader, Android release APK or iOS signed archive was produced in this pass.

## 8. Backend Findings

Shared BookingPrivacy projections address the original provider-home and customer-contact leaks. SUPPORT read gates and filtered inbox sources address the broad admin reads. Unsave transactions and eager copied review tags address the prior persistence-boundary failures. The FCM outcome count and log scrubbing changes address the demonstrated counting/raw-message problems.

V34 and destination snapshots correctly freeze new booking DTOs; amendment checks customer ownership, own nonarchived address, home-service state, cutoff and radius, resets accepted visits to pending for reconfirmation, and notifies the provider. R4-02 is a missed downstream projection. @Version and provider locks exist; no lost-update incident is asserted solely because amendment starts with findById. Real PostgreSQL concurrency and notification/commit failure cases remain required.

Image headers now have per-side and estimated decode-memory bounds before decoding, in addition to area/progressive limits. The specific skinny-PNG finding is closed by source and passing tests. This does not certify a 128 MiB real peak for every decoder or a safe aggregate peak under concurrent uploads; use bounded-heap and production concurrency measurements.

The profile-mixing guard, HTTPS/public-host gateway rules, expiry-based temporary-password session cutoff and 2xx refusal parsing are substantive improvements. Optional host allowlists and generic refusal parsing need deployed/provider verification. Unknown/non-JSON successful gateway bodies remain treated as accepted; typed provider-specific acceptance receipts remain a follow-up.

The 2,089-line BookingServiceImpl still coordinates many responsibilities. Refactoring it is lower priority than fixing the concrete safety/recovery/session defects and proving invariants.

## 9. Dashboard Findings

CSV formula neutralization, policy-draft ordering, remaining payout balance, partial moderation writes, review visibility, capability navigation, retry errors and dialog/keyboard primitives address the reviewed defects. Global refresh now waits for subscribed loaders. Truncated queues announce the cap.

R4-03/04/07 remain despite the new session and SOS safeguards. Session teardown needs to cover both pending bodies and data already loaded. Stale status must follow accepted reads, not component data changes. Server-side access checks correctly remain authoritative for fresh requests.

App.jsx is 5,363 lines. Many queues still gather up to 50 pages into memory instead of using server-driven page/search controls. The notice makes truncation visible but does not make totals/worklists complete or bound rendering/request cost adequately for large histories. Native browser storage/cookies, two-tab logout/login ordering and screen-reader behavior are still gates. [Dashboard review](dashboard.md) records screen-level outcomes.

## 10. Database Findings

| Entity group | Relationship / invariant |
| --- | --- |
| Users and provider profiles | Account role/status, owned provider, permissions, encrypted TOTP, password/session cutoff and expiry |
| Services, staff, availability and assignments | Provider ownership, valid service/staff association, active historical references and time windows |
| Bookings | Customer/provider/service/staff, optional owned address, state/timestamps, idempotency/version, frozen prices/commission and V34 destination |
| Reviews and tags | Booking/direction uniqueness, rating aggregates, hidden/moderation status and lazy collection boundaries |
| Commission ledger / payout reports | Unique booking obligations, monetary arithmetic, frozen report membership and settlement evidence |
| Saved providers/addresses/trusted contacts | Owned resources, uniqueness/default handling and archived history |
| Chat/notifications/push/safety/delivery | Booking participation, read state, recipient identity and durable incident/delivery retry state |
| Complaints/moderation/audit | Support case lifecycle, permission-sensitive reads and attributed decisions |
| Terms/settings/revocations | Per-role version acceptance, override hierarchy, durable token rotation/revocation |

Foreign keys, targeted uniqueness, soft/history-preserving deletion and V13/V16 indexes are present. V15/versioning and pessimistic locks protect selected concurrent paths. H2 validates structure and many assertions; it cannot establish PostgreSQL locking, deadlocks, isolation or production query plans.

V34 backfills from the currently stored address and marks destination_backfilled. It cannot reconstruct the originally agreed historical destination. Rehearse on a production copy, quantify affected rows and communicate provenance before deployment. Older application versions do not populate the new snapshot fields; rollback-created rows can fall back to the mutable relation until explicitly handled.

V25/V30 NOT VALID checks enforce relevant writes without proving every legacy row is clean. Assess/backfill violations before constraint validation. Java V19 migration cost, Flyway checksums and actual deployed schema remain operational checks. Measure lazy DTO association loads, history aggregates, wildcard search and scheduling queries with EXPLAIN/query counts; no index removal is recommended without evidence.

I-03 remains mitigated: dump and tar are separate snapshots. A manifest and missing/orphan report expose mismatch; they do not produce transactional database/files consistency. R4-01/06 add concrete recovery concerns. The restored database reference query can fail and still feed an empty reconciliation report, so operators must require a successful scan before trusting a zero-missing result.

## 11. Security Audit

| Surface | Result / remaining boundary |
| --- | --- |
| Authentication | BCrypt, purpose-typed JWTs, OTP/challenge replay controls, token rotation/revocation and account cutoffs are present; temporary-password sessions now end at expiry |
| Admin sessions | Memory access token; HttpOnly/Secure/SameSite refresh cookie; custom refresh header; idle/session-end signal and cross-tab refresh locking. R4-03/04 remain |
| Authorization / IDOR | Controller gates plus owner/participant comparisons reviewed; sensitive read matrix narrowed to SUPPORT/FINANCE/SUPER_ADMIN. Real MFA-enrolled account matrix still required |
| Mobile sessions | Secure storage and request generations; R4-05 concerns destructive stale handlers and state loss |
| Input / injection | Bean Validation plus explicit map/query/state/file bounds; parameterized repository paths. No new SQL/command injection or server XSS exploit established |
| Files | Header/decode limits, public normalization, separate private authorization/encryption. R4-06 is a new plaintext retained database artifact |
| CSRF/CORS/edge | Refresh-cookie header/origin rules and production edge configuration are present; verify actual origins, cookie attributes, proxy trust and TLS behavior |
| SSRF/integrations | HTTPS/public literal-host guard and optional allowlist; deployed DNS/egress and exact provider contracts remain unverified |
| Logging / secrets | LogSafe and opaque IDs reduce demonstrated leakage. No secret values are included here; runtime/history/artifact/key custody still require operator evidence |
| Recovery / retention | R4-01/06; offsite lifecycle, immutability, least privilege and key escrow remain external gates |

This is a source and synthetic runtime review, not a penetration-test certificate. No real user account, external message, cloud mutation or production restore was performed. No newly established hardcoded production secret is reported; ignored local secrets and deployed environment credentials were not published or certified.

## 12. API Audit

[api-inventory.md](api-inventory.md) covers **183 mapped handler methods across 29 controllers**, up from 181. It includes verb/route, inputs, exact annotations, request DTO constraints, statically reachable operations, response types and error keys. A multi-verb Java handler counts once. [api-flows.md](api-flows.md) explains conditional ownership/business/transaction behavior for every controller family.

Two new handlers:

| Route relative to /api | Access / validation | State / response / consumer |
| --- | --- | --- |
| PATCH /bookings/{id}/destination | CUSTOMER; own booking/address; @NotNull savedAddressId; nonarchived address, home service, PENDING or ACCEPTED, accepted cutoff and radius checks | Copies snapshot; accepted → pending; notification; BookingDto; no mobile consumer yet |
| PATCH /provider/mode/travel-buffer?minutes= | PROVIDER; resolves own provider; integer 0–60 | Changes only travel-buffer property; success envelope; mobile schedule stepper uses it |

The Springdoc contract snapshot adds operation/schema property-name drift detection. It does not establish field semantics, field privacy, enum compatibility, examples, error contract or that every consumer uses the operation. R4-02 is an example of semantically inconsistent projections despite a stable schema.

Backend read-RBAC tests, privacy/state projection tests, snapshot tests, persistence-boundary tests and gateway/guard tests pass in this revision. Fresh requests still enforce protected admin capabilities; R4-03 does not show a successful unauthorized backend read.

## 13. Mobile / Backend / Dashboard Mismatches

| Boundary | Current outcome |
| --- | --- |
| Destination snapshot → SOS | Open R4-02: booking and SOS textual destination disagree |
| Destination amendment → mobile | API exists, no screen/caller; product follow-up and coordinated rollout |
| API session generation → dashboard body | Open R4-04: blob body/side effects outside the final guard |
| Account hint → admin view identity | Open R4-03: new permissions but old mounted restricted rows |
| Dio obsolete-response signal → auth Bloc | Open R4-05: ordinary failure and unguarded destructive startup branch |
| Queue freshness → UI claim | Open R4-07: independent initial/manual/poll streams |
| Onboarding server stage → client recovery | Improved but incomplete durable staff/input checkpoint |
| Gateway 2xx → delivery guarantee | Generic refusal parsed; actual provider acceptance/delivery still unverified |
| Backups → restored references | I-03 mitigated; snapshot consistency and successful reconciliation still needed |
| CI jobs → staging release | Open R4-08; deployment does not wait for every relevant check |

Coordinate backend, dashboard and mobile rollout. New SUPPORT checks can deliberately produce 403 for admins who previously read broadly; this is an access-policy change to communicate and validate, not a reason to widen the gate again.

## 14. Dead / Duplicate / Unused Code

No code was deleted. Duplicate mapper policy was reduced through BookingPrivacy, but SafetyService still has the divergent destination projection. Generic gateway refusal parsing removes some duplication without replacing provider-specific contracts. Dialog primitives consolidate interaction behavior.

The amendment handler has no mobile consumer; that is a missing workflow, not proof the API should be removed. Mock dashboard fixtures, local/test helpers, schema snapshots, integration scaffolding and platform targets have conditional uses. Static absence of imports or calls is not sufficient to declare externally invoked endpoints/jobs dead. Defer deletion/refactoring until references and production use are measured.

## 15. Performance Risks

- One host and local storage remain a common failure/capacity domain. Quantify recovery time, disk headroom, simultaneous staging/previous/safety copies and backup tar growth.
- Admin 50-page fetches and thousands of rows remain expensive; implement server paging/search and stable totals after measuring critical workflows.
- BookingServiceImpl/App.jsx size increases change/regression cost; split around verified business boundaries once urgent invariants are covered.
- Measure PostgreSQL scheduling overlap, lock contention, lazy DTO loads, wildcard searches, ledger sweeps and aggregate histories under realistic data.
- Image dimensions/estimated memory now reject the original attack, but parallel decodes and progressive/image implementation overhead require bounded heap tests.
- Polling, gateway retries, Redis fallback, background sweep ownership and notification fanout need fault/load evidence. No supported maximum-user count can be inferred from passing unit tests.
- Frontend production JS remains 345.82 kB, 100.54 kB gzip; bundle splitting is secondary to correctness and observed device/network cost.

## 16. Missing Tests

Convert the audit reproductions into regression tests after fixes: rollback itself failing and outer app staying stopped; SOS address after edit/amendment; cross-tab already-loaded restricted views; delayed blob body after logout; mobile cold-start cleanup and obsolete auth failures; shared ordering for initial/manual/poll SOS requests; encrypted safety-copy retention.

Still needed: real PostgreSQL V34 and concurrency suites; real Docker restore/full-disk/permissions/drill; promtool alert tests plus delivered alerts; native browser cookie/two-tab/error scenarios; device process death and notification taps; real provider sandbox refusal/delivery; offsite-only restore with escrowed keys; release builds/artifact scans; measured load. Their absence remains material even though the local suites pass.

The existing test additions increase coverage from 411→483 backend, 120→164 admin and 178→221 Flutter. Audit-only probes intentionally assert the current failure outcomes and must be inverted/expanded when turned into project regression tests. They were not added to the application repository.

## 17. Production Readiness Checklist

| Gate | Status / evidence needed |
| --- | --- |
| Source launch blockers | Open: R4-01/02/03; address Medium findings before signoff |
| Automated local suites | Fresh green results above; available logs attached |
| Dependencies | Dashboard production npm scan green; backend CVE scan and complete release artifacts still unverified |
| PostgreSQL/Flyway | Open: real DB + V34 production-copy rehearsal and backfill provenance |
| Recovery | Open: R4-01/06, real restore/rollback/full-disk/offsite drill |
| Backup consistency | Mitigated only; concurrent writers and successful reference reconciliation required |
| On-call / integrations | Open: provider sandbox and delivered emergency/monitoring messages |
| Secrets / offsite | Open: runtime configuration, lifecycle/immutability/IAM/key escrow evidence |
| Admin browser | Open: two-tab sessions, body completion, MFA read matrix, accessibility |
| Mobile release/device | Open: process death, upload retry, tap/deep link, keyboard/RTL, signed release artifacts |
| CI/deployment | Workflow present; execution unverified; R4-08 gate dependency open |
| Capacity/availability | Open: representative k6/database/storage measurements and recovery objectives |

The existing [launch-signoff.md](<D:/AIWA PROJECT/AIWA/docs/launch-signoff.md>) has 34 open rows. This audit does not fill owner/date/evidence without actual execution.

## 18. Recommended Action Plan

1. **P0 — protect recovery and incident handling:** fix R4-01/02/03 with the reproduced cases; ensure no app restart after partial filesystem rollback and no wrong SOS address/restricted old-account view.
2. **P1 — complete session and freshness boundaries:** fix R4-04/05/07; include failures, body consumption, storage deletion, manual loading and data already mounted.
3. **P1 — retained backups:** fix R4-06 and verify real recovery with encryption, disk pressure and retention.
4. **P2 — deployment evidence:** add the appropriate R4-08 release gate; run real PostgreSQL, promtool, Docker restore and CI; rehearse V34 before rollout.
5. **P2 — complete product recovery:** decide/build destination amendment UI and durable onboarding checkpoints; perform the browser/device/provider/offsite checks.
6. **P3 — measured scale and maintainability:** server paging, typed integration contracts, bounded query/image/load behavior, service/page modularity and an availability/storage plan.

Keep the earlier reports as history. Use this report and [remediation-status.md](remediation-status.md) as the current status. Do not treat the round 3 statement “all repository-actionable defects are fixed” as verified for this release.
