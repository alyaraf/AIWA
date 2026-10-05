# Round 3 remediation record — 2026-10-05

Baseline audited: `ac67446495a22ce11b8f2071d0f1599f3c0cdee4` (`main`, unchanged when remediation began). The original findings
in [audit.md](audit.md) are history and are not edited. This page records what was done about each one, with the evidence.

**How to read the status column**

- **Fixed** — changed in the repository, with a regression test that fails on the old behavior where practical, and the suites below pass.
- **Fixed (code) + gate** — the repository change is done and tested, but a check that needs a device, a provider, the cloud or a deployed stack is still open (named in the last column and in `docs/launch-signoff.md`).
- **Mitigated** — the risk is reduced and documented, but not removed.
- **Disproved / Confirmed** — for the potential risks: what verification showed.
- Nothing here claims a production gate passed. See the readiness decision at the end.

## Verification results (this pass)

| Suite | Result | Baseline |
| --- | --- | --- |
| Backend, JDK 17.0.19, `mvn -o test` | **483 run, 0 failures, 0 errors, 0 skipped** | 411 |
| Admin, Node 20.20.2, `vitest run` | **164 tests / 28 files pass**; `vite build` OK (345.82 kB JS, 100.54 kB gzip) | 120 / 20 |
| Flutter 3.47.5, `flutter analyze` / `flutter test` | **no issues / 221 pass** (English and Arabic goldens included) | 178 |
| `deploy/backup/backup_test.sh` | 32 pass | 31 |
| `deploy/backup/uploads_swap_test.sh` (new, failure injection) | 33 pass | — |
| `deploy/restore_flow_test.sh` (new, order of `restore.sh`) | 23 pass | — |
| Real browser (Vite in mock mode, built-in browser) | dialog focus/inert/Escape, keyboard Bookings rows, stale SOS banner on `offline` observed; this also found a render-time crash in Bookings that unit tests missed, now fixed and covered by `App.screens.smoke.test.jsx` | not run |

Not run here (no daemon, credentials, devices or network): PostgreSQL/Redis (Docker Desktop did not start), promtool, the CI
workflow itself, `npm audit` (the advisory endpoint returned an error; `package.json`/lockfile are unchanged, so the audited
result of 0 still describes the dependencies), k6, device and provider tests, anything against a deployed environment.
Raw outputs: [validation/remediation-results.md](validation/remediation-results.md).

## Status table — confirmed findings

| Finding ID | Status | Fix | Files | Tests / evidence | Remaining dependency |
| --- | --- | --- | --- | --- | --- |
| B-01 | Fixed | Header-only checks before any decode: per-side cap (16384), decoder working-memory estimate cap (128 MiB), plus the existing pixel ceilings; configurable via `PUBLIC_MAX_IMAGE_DIMENSION` / `PUBLIC_MAX_DECODE_WORKING_BYTES` | `FileStorageServiceImpl.java`, `application.yml`, `deploy/docker-compose.prod.yml`, `deploy/.env.example` | `FileStorageDecodeLimitsTest`: the 20,000,000 × 1 PNG header is refused with 400 and nothing stored; wide-but-small-area refused; ordinary photo still stored | Memory-bounded subprocess/live heap test on staging |
| B-02 | Fixed | One audience/state rule (`BookingPrivacy`): a home provider's exact address/pin only while the visit is live; PENDING and every terminal state and all alternative-provider suggestions get the public projection | `BookingPrivacy.java`, `BookingServiceImpl.java` | `BookingPrivacyProjectionTest` (every `BookingStatus` × home provider / venue × customer) | Product sign-off of the "live states only" rule |
| B-03 | Fixed | Provider dashboard uses the same contact projection (`customerFor`) | `ProviderServiceImpl.java`, `BookingPrivacy.java` | `BookingPrivacyProjectionTest` (dashboard, every status) | — |
| B-04 | Fixed (code) + gate | Read matrix: SOS, reported chat, reviews, review reports, flags, staff history need SUPPORT; inbox filters each source by capability; dashboard nav/actions mirror it | `SafetyController`, `ChatController`, `ReviewController`, `AdminController`, `AdminProviderSettingsController`, `AdminInboxController`, `Perms.java`; admin `App.jsx` (`NAV_REQUIRES`, `canManageTarget`) | `AdminReadExportRbacApiTest` (none / Finance / Support / Super × each route, empty inbox), `navPermissions.test.js` | Run the matrix on staging with enrolled MFA accounts (gate 31) |
| B-05 | Fixed (API) + follow-up | Booking keeps an immutable destination snapshot (V34, backfill marked `destination_backfilled`, never invented); all participants and admin read the snapshot; explicit `PATCH /bookings/{id}/destination` (customer, home service, PENDING or ACCEPTED within the cutoff, radius check, accepted → PENDING for re-confirmation, provider notified) | `V34__booking_destination_snapshot.sql`, `Booking.java`, `BookingServiceImpl.java`, `BookingController.java`, `AmendDestinationRequest.java`, `AdminController.java`, i18n | `BookingDestinationSnapshotApiTest` (edit address → booking unchanged for both parties; radius, ownership, state, notification); `MigrationSchemaValidationTest` runs V34 | **No mobile screen calls the amend endpoint yet** (API is ready); V34 rehearsal on production data (gate 27) |
| M-01 | Fixed (code) + gate | Transport drops any successful answer sent under an earlier session (`SessionChangedException`); repository and bloc compare the session generation before caching/emitting; the app-wide notification bloc is reset on sign-out/account switch | `api_client.dart`, `exceptions.dart`, `failures.dart`, `secure_storage.dart`, `auth_repository_impl.dart`, `auth_bloc.dart`, `notification_bloc.dart`, `app.dart` | `auth_session_race_test.dart` (late profile after logout; late A after B signed in, cache is B's), `api_client_session_test.dart` (transport drop, no offline banner), `notification_paging_test.dart` | Device check with a slow network (gate 30) |
| AD-05 | Fixed (code) + gate | SOS list shows last-confirmed time and "Live / Not live", a persistent alert banner on failure, hang timeout, no overlapping or out-of-order polls, offline/online events, never says "No open SOS alerts" while stale, retry | admin `App.jsx` (`SafetyQueue`) | `Safety.stale.test.jsx` (8 cases incl. recovery); observed in a real browser | Exercise the real on-call SMS/phone channels on staging (gate 15) |
| I-02 | Fixed (code) + gate | Uploads extracted and verified inside the volume before anything live changes; swap by atomic renames keeping the previous files; safety dump of the live database; failed swap rolls files and database back together; backend kept stopped only when nothing can be put back | `deploy/restore.sh`, `deploy/backup/uploads_swap.sh`, `docker-compose.prod.yml` (mounts) | `uploads_swap_test.sh` (failure at every rename, damaged archive, rollback, purge), `restore_flow_test.sh` (extraction / DB / swap failures, double failure), `backup_test.sh` | Drill on staging with real volumes and a full disk (gate 24) |

## Medium

| Finding ID | Status | Fix | Files | Tests / evidence | Remaining dependency |
| --- | --- | --- | --- | --- | --- |
| B-06 | Fixed | Quick tags copied inside the transaction | `AdminController.java` | `PersistenceBoundaryApiTest` (OSIV off, persisted tags, hidden flag) | — |
| B-07 | Fixed | Unsave runs in a transaction; deleting twice is idempotent | `SavedController.java`, `SavedProviderRepository.java` | `PersistenceBoundaryApiTest` | — |
| M-02 | Fixed | Upcoming asks the server for the live statuses; an empty filtered page no longer hides "Load more" | `my_bookings_page.dart` | `my_bookings_upcoming_test.dart` (live-status query, Load more kept), `booking_query_race_test.dart` | Device check |
| M-03 | Fixed | A multipart body is cloned before the 401 → refresh → retry | `api_client.dart` | `api_client_session_test.dart` real `MultipartFile.fromFile` upload; the test fails without the clone (verified) | Device upload with an expired token |
| M-04 | Fixed | Identity stays while the session is valid; `AuthAuthenticated.refreshError`; only a 401 signs out; cold start with a server error opens the cached account | `auth_state.dart`, `auth_bloc.dart` | `auth_session_race_test.dart` | — |
| M-05 | Fixed (code) + gate | Server reports `providerOnboarding` (NO_PROFILE / NEEDS_DOCUMENTS / SUBMITTED, derived from stored data); profile and staff steps are safe to repeat (existing profile is detected, staff deduplicated); the pending screen says what is missing and offers "Continue setup" / "Upload documents" | `ProviderOnboarding.java`, `AuthController`, `AuthServiceImpl`, `ApiResponse.java`, `auth_repository_impl.dart`, `user_entity.dart`, `user_model.dart`, `provider_pending_page.dart`, l10n | `ProviderOnboardingTest`, `provider_onboarding_test.dart`, `provider_pending_onboarding_test.dart` | Kill-and-relaunch on a device (gate 30) |
| M-06 | Fixed | Narrow `PATCH /provider/mode/travel-buffer` (0–60); the stepper no longer sends the business profile | `ProviderModeController.java`, `provider_manage_repository.dart`, `provider_schedule_page.dart` | `PersistenceBoundaryApiTest` (name/bio/address untouched), `provider_buffer_update_test.dart` | — |
| M-07 | Fixed | Sign-up shows the full current role policy before consent and pins its version; acceptance is recorded for that version only, and a newer version sends the person back to read it; re-accept shows the whole text | `terms_page.dart`, `preferences_page.dart`, `terms_reaccept_page.dart`, `auth_repository.dart` (`acceptShownTerms`), l10n | `terms_pinned_acceptance_test.dart`, `terms_full_text_test.dart`, `onboarding_test.dart` | Legal review of the wording (not asserted) |
| M-08 | Fixed | The deferred booking is consumed only by the step that ends on Home | `app_router.dart`, `permission_priming_page.dart` | `resume_after_signup_test.dart` | Device walk-through |
| M-10 | Fixed | Query generation: older first-page and continuation answers are dropped; the page counter moves only for the current query | `booking_bloc.dart` | `booking_query_race_test.dart` (reversed completion, late continuation, double tap) | — |
| M-11 | Fixed | Page advances only after success; one continuation at a time; failure keeps the list, shows the error and retries the same page | `notification_bloc.dart`, `notification_state.dart`, `notifications_page.dart` | `notification_paging_test.dart` | — |
| AD-01 | Fixed | Formula neutralization (leading whitespace/control characters too) for the dashboard export and the server CSVs | admin `csv.js`, `App.jsx`; `AuditController.cell` | `csv.test.js`, `AuditCsvEscapingTest` | Open an export in a real spreadsheet |
| AD-02 | Fixed | Draft tied to the type it was loaded for; stale answers dropped; publish refused while loading | admin `App.jsx` (`TermsEditorPanel`) | `TermsEditor.race.test.jsx` (reversed completion) | — |
| AD-03 | Fixed | Settled/owed derived from the refreshed balance; the confirmed payout is shown beside the remaining debt | admin `App.jsx` (`SettlementDetail`) | `SettlementDetail.balance.test.jsx` (128.40 confirmed, 45.00 still owed and actionable) | — |
| AD-04 | Fixed (code) + gate | One authenticated transport for requests, document images and exports; idle limit enforced by a timer, focus and every helper; one session-end signal clears all views | admin `api.js`, `App.jsx` | `api.session-integrity.test.js`, `api.idle-timeout.test.js` | Two-tab browser check against the deployed API (gate 29) |
| AD-06 | Fixed | Every loader subscribes to the global Refresh; success is acknowledged only after the fetches succeed | admin `App.jsx` (`useRefreshSignal`) | `SettlementDetail.balance.test.jsx`, `App.screens.smoke.test.jsx` | — |
| AD-07 | Fixed | Warn/suspend + close are explicit: no refresh between writes, the row stays with "Retry closing" when only the second step failed, no duplicate action | admin `App.jsx` (`Flags`, `runAction`) | `Flags.partial.test.jsx` | — |
| AD-09 | Fixed | `hidden` preserved and shown; Restore action; export includes visibility | admin `api.js`, `App.jsx` | `api.session-integrity.test.js` (real DTO shape) | — |
| AD-11 | Fixed (code) + gate | One `ModalFrame` (named, focus trap, Escape, restore focus, inert page, portal) for every dialog; clickable rows are keyboard controls; toasts survive the inert page | admin `Dialog.jsx`, `App.jsx` | `Dialog.a11y.test.jsx`; observed in a real browser | Screen-reader pass (gate 29) |
| AD-12 | Fixed | The e-mail is labelled a public support contact; the copy names the real SOS and dispute routes | admin `App.jsx` | text review | Real on-call delivery test (gate 15) |
| I-01 | Fixed (code) + gate | Selector uses `mountpoint="/"` over every real filesystem; `HostMetricsMissing` fixed; promtool unit tests and a CI job | `deploy/monitoring/alerts.yml`, `alerts_test.yml`, `.github/workflows/ci.yml` | `alerts_test.yml` (**not executed here**: no Docker; the CI job runs it) | CI green; a delivered low-disk alert on staging (gate 26) |
| I-03 | Mitigated | Dump-first order documented as the guarantee; per-pair manifest; reconciliation report (missing / orphan) after every restore | `backup.sh`, `reconcile_uploads.sh`, `uploads_references.sql`, `restore.sh`, `docs/runbooks.md` | `backup_test.sh` (manifest), `restore_flow_test.sh` (report lists the missing file) | A point-in-time snapshot (volume snapshot or brief write pause) if a stronger guarantee is required; concurrent-writer restore drill (gate 25) |
| I-04 | Fixed | `aiwa-backend/docker-compose.yml` is loopback-only PostgreSQL/Redis with no backend service; README and `docs/release.md` corrected | `aiwa-backend/docker-compose.yml`, `README.md`, `docs/release.md` | file/guard comparison | — |
| I-05 | Prepared (external) | Off-site retention policy, lifecycle/lock/IAM/escrow requirements and evidence list written; sign-off rows added | `docs/runbooks.md`, `docs/launch-signoff.md` | — | Bucket configuration, key custody and an off-site-only restore (gates 3–5, 28) |

## Low

| Finding ID | Status | Fix | Files | Tests / evidence | Remaining dependency |
| --- | --- | --- | --- | --- | --- |
| B-08 | Fixed | One outcome increment per rejected FCM send | `FcmPushService.java` | `FcmPushServiceTest.aRejectedPushCountsOnce` | — |
| I-06 | Fixed | Opaque user id in rejected-session warnings; `LogSafe.scrub` on provider/driver messages | `JwtAuthFilter.java`, `LogSafe.java`, SMS/e-mail/FCM/safety/admin adapters | `LogSafeTest` | Log retention/access review in the deployed environment |
| M-09 | Fixed (code) + gate | Local-notification launch details feed the same pending-tap pipeline; booking ids from payloads must be positive integers | `push_service.dart`, `notification_routes.dart` | `push_launch_payload_test.dart`, `notification_routes_test.dart` | Terminated-app tap on Android and iOS (gate 30) |
| AD-08 | Fixed | Capability matrix drives navigation and admin-target actions | admin `App.jsx` | `navPermissions.test.js` | — |
| AD-10 | Fixed | Error cleared on load and on success | admin `App.jsx` | `SettlementDetail.balance.test.jsx` | — |
| AD-13 | Fixed (notice) | Cap kept; truncated lists carry a mark and every large queue shows "Showing only part of this list" | admin `api.js`, `App.jsx` | `api.session-integrity.test.js` (51 pages of 200 → 10,000 rows, marked) | Server-side paging/search is the real fix; not built, the cap was not removed |

## Potential risks (verified before changing behavior)

| ID | Outcome | Action | Evidence | Remaining dependency |
| --- | --- | --- | --- | --- |
| P-01 | Confirmed (mixing `prod` with `local`/`test` skipped the guard) | `ProfileIsolationGuard` refuses the mix on every profile | `ProfileIsolationGuardTest` | Print the resolved profiles on staging (gate 32) |
| P-02 | Confirmed (non-blank URL accepted `http`, localhost, private addresses) | https, public host, no credentials, optional host allow-list | `ProductionGuardConfigTest` | Resolved URLs and egress on staging (gate 32) |
| P-03 | Confirmed as an ordering race in the client (a slow logout can finish after the next sign-in's cookie) | `login` waits for a sign-out in flight | `api.session-integrity.test.js` | Real-browser/two-tab check (gate 29) |
| P-04 | Confirmed (late success was returned) | Stale-session guard in the transport | `api.session-integrity.test.js`, `api.cross-tab-refresh.test.js` | Same |
| P-05 | Confirmed for the Docker build (https/mock-off were not enforced for arbitrary builds) | Dockerfile refuses a non-https API URL and forces `VITE_USE_MOCKS=false` | Dockerfile review | Inspect the built artifact of the release image |
| P-06 | Policy gap confirmed; decision implemented | Sessions started on a temporary password end when it expires | `TempPasswordSessionApiTest` | Policy acceptance (gate 33); a forced change-password screen is a product decision |
| P-07 | Contract unverified | E-mail adapter now treats a refusal in a 2xx body like the SMS adapter | `HttpEmailServiceTest` | Provider sandbox send (gate 21); no failed real gateway send was observed in the audit either |
| P-08 | Needs runtime verification | Not a repository item | — | Secrets, IAM, history and artifact scans by the operators |

## Dead / duplicate code

`Placeholder` in `App.jsx` had no reference anywhere (including tests) and was removed. The repeated booking mapper that
leaked locations and contacts is now behind `BookingPrivacy`; the other duplicated mappers and loaders were left until
their own tests exist. Nothing else was deleted: the legacy `settle` endpoint, dev profile code, mock dashboard, legacy
`provider_images` data and cookie-cleanup paths are intentional or data-dependent. No dependency was added, removed or upgraded.

## Roadmap items

| Roadmap item | Status |
| --- | --- |
| P0 / P1 / P2 findings above | Done as listed |
| Stable API contract | **Done**: `ApiContractSnapshotTest` records all 183 operations and the DTO property names (`src/test/resources/api-contract/`); changes fail the build until reviewed and regenerated |
| SBOM / dependency governance | **Added** a CI `sbom` job (CycloneDX for backend and admin); **not run here** |
| CI evidence for new suites | **Added** `monitoring-rules` and `backup-restore` jobs; **not run here** |
| Extract the booking service, typed provider contracts, modular admin pages, measured HA/storage plan | **Not done**: these are refactors and capacity work that need workload data and are riskier than the defects fixed; documented, not started |

## Database and deployment compatibility, rollback

- **Migration V34** (`bookings`: `destination_label/address/latitude/longitude`, `destination_backfilled boolean NOT NULL
  DEFAULT false`, `destination_amended_at`) is additive. Existing rows with a saved address are backfilled from that address as it
  is *now* and flagged `destination_backfilled = true`, because the originally agreed text was never recorded. V1–V33 are untouched.
  Rollback: the previous jar ignores the new columns; a booking the old jar creates has no snapshot and the new code falls back to
  the saved-address relation for it. Run V34 on a copy of production first (gate 27).
- **API additions** (backward compatible): `PATCH /bookings/{id}/destination`, `PATCH /provider/mode/travel-buffer`,
  `UserDto.providerOnboarding`, `BookingDto.destinationAmendedAt`.
- **Behavior changes that need the clients updated together:** the admin read matrix (an admin without SUPPORT now gets 403
  on SOS, reported chat, reviews, flags, staff and a filtered inbox) — deploy the new dashboard with the backend; a
  new mobile build needs the backend first (`travel-buffer` does not exist on the old one); a session on a temporary password
  now ends at expiry.
- **Compose/backup:** the `backup` service mounts two new scripts, so run `docker compose -f docker-compose.prod.yml up -d
  backup` before the first `restore.sh`. New optional variables: `AIWA_GATEWAY_ALLOWED_HOSTS`, `PUBLIC_MAX_IMAGE_DIMENSION`,
  `PUBLIC_MAX_DECODE_WORKING_BYTES`. The backend now refuses `http`/private SMS and e-mail URLs and `prod` + `local`/`test`.
- **Rollback of code** is a redeploy of the previous release tag; nothing here deletes data.

## Production-readiness decision

**Not ready for production.** The repository-actionable defects of the audit are fixed and tested, and the suites are green, but
the evidence required for launch is still missing and cannot come from this machine:

1. Staging: the new restore flow with real volumes and failures, V34 on production-like data, alert delivery (including a real
   low-disk alert), the B-04 matrix with MFA accounts, resolved profiles/gateway configuration.
2. Devices: Android and iOS (account switch, expired-token upload, onboarding kill/resume, local-notification launch, permissions).
3. Browsers/assistive technology: two-tab session behavior against the deployed API, a screen-reader pass.
4. Cloud/operations: off-site bucket lifecycle/lock/IAM, key escrow, an off-site-only restore, secrets and history scans.
5. Providers: SMS, e-mail and push sandbox sends, real SOS routing.
6. CI: a green run of every job including the new ones, the NVD scan, image scans, the SBOM.
7. Measured load, soak and query plans on staging.

Staging is the next step, with the gates in `docs/launch-signoff.md` (rows 24–34 added) as its checklist.
