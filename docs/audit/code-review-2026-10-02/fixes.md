# Fixes for the 2026-10-02 code review

Branch `fix/code-review-2026-10-02`, from `af72941`. Not pushed, no pull request.
Each fix has a test that was run against the unfixed code first (it failed) and
again after the fix (it passed). The before/after logs and the reviewers'
verdicts are in the run archive `.claude/orchestrate-runs/20261002-1546/` of the
worktree `.claude/worktrees/cr` (git-excluded, not committed).

Every unit was checked by an independent reviewer. At the end, two more
reviewers checked the whole branch: one for code, one for security.

## Findings

| ID | Status | Commits | Files changed (main) | Covering tests | Not verified / notes |
|---|---|---|---|---|---|
| CR-01 | fixed | 2034f85, a045ded, 9721b30 | `RedisRateLimitFilter`, `AuthServiceImpl`, `TotpService`, `User`, `UserRepository`, `AuthController` (server-time), `AdminUsersController` (reset lifts lock), `V20__login_attempt_limits.sql`, admin `App.jsx`/`api.js` (30 s hint) | `SignInLimitsApiTest` (7, incl. `/auth/logi%6e` above the limit), `TotpServiceTest.acceptsOneStepOfDriftButNotTwo`, `SupportResetLiftsSignInLockApiTest` | The encoded-path bypass was **real**: the test got past the limiter on the unfixed code. The limiter now uses the decoded path. Checked with MockMvc only, not behind real Tomcat/Caddy. V20 not run on PostgreSQL 16. Trade-offs: anyone who knows an email can lock that account for 15 min, and 429 vs 401 reveals that an account exists. Password minimum length (6) unchanged. |
| CR-02 | fixed | d0c0728, f520321 | `User` (setters and builder go through `Identifiers`), `AdminUsersController`, `AdminBootstrapConfig`, `config/V19__Normalise_identifiers.java` (Java Flyway migration), `AccountDeletionService` (scrubs collision rows) | `AdminUsersControllerTest` (7 new), `AdminBootstrapConfigTest`, `IdentifierNormalisationMigrationTest`, `ApiFlowIntegrationTest.aPhoneSavedBySupportInLocalFormatStillSignsInAndResets` / `.anAdminEmailMustBeAnEmailAndUniqueWhateverItsCase`, `AccountDeletionIdentifierCollisionsTest` | V19 is Java so it can call `Identifiers`. `MigrationSchemaValidationTest` runs only SQL files, so V19 has not run on PostgreSQL. Colliding rows are left as stored and listed in `identifier_collisions`. **Resolve them by hand before go-live**: two rows that differ only by email case still make sign-in for that address fail (this predates the branch). |
| CR-03 | fixed | 53b5262 | `BookingServiceImpl`, `Booking`, `V21__payment_resolution.sql` | `ApiFlowIntegrationTest.aDisputeTheAdminResolvedAsPaidCannotBeReopened`, `.aSecondNotPaidIsRefused`, `PaymentDisputeWindowTest` | Disputes an admin resolved as PAID before V21 have no stored resolution: the customer can still say "not paid" once inside the window. V21 not run on PostgreSQL 16. |
| CR-04 | fixed | 13dc3db | `BookingServiceImpl` | `BookNowClosingTimeTest` (3) | — |
| CR-05 | fixed | e99ff1b, f799975, 68bede8 | backend `AuthController`, `AccountController`, `AuthServiceImpl`, `User`, `V22__pending_email.sql`; app auth and profile flows, `secure_action_sheet.dart`, ARB files | `VerifiedEmailApiTest` (5), app `profile_security_flows_test`, `pending_email_test`, `pending_email_resend_test`, `profile_security_contract_test` | Emails already stored stay as they are (nobody knows which were verified). Wrong passwords on these changes count toward the CR-01 lock. Not tried on a device. |
| CR-06 | fixed | ecf79a1 | `SettlementController`, `CommissionLedgerEntry`, `CommissionLedgerRepository`, `V23__payout_report_freeze.sql`, admin `api.js`/`App.jsx` | `PayoutReportFreezeTest` (2), admin `SettlementDetail.payout.test.jsx` (2) | Not changed: settling a single entry can still clear the report flag, and the admin page says "Settlement confirmed" after a partial payout until it is reopened. V23 not run on PostgreSQL 16. |
| CR-07 | fixed | 17ffbce | `SettlementController` | `SettlementControllerTest.reminderStatesDuePlusOverdue` | — |
| CR-08 | fixed | d936f39 | `SafetyService`, `SosTextRetryScheduler`, `PushExecutorConfig` (own SOS executor), `SosDelivery`, `V24__sos_delivery_retry.sql`, `deploy/monitoring/alerts.yml` | `SosTextRetryTest` (7) | Retries continue until the SOS is closed (no cap). On first deploy, texts of SOS alerts still open are re-sent, so close stale ones first. `supportAlerted` is now true only once an on-call text was sent. The scheduler is off in the test profile; promtool not run. |
| CR-09 | not fixed | — | — | — | **Waiting for your rule** (when SOS is allowed). Not touched. |
| CR-10 | not fixed | — | — | — | **Waiting for your rule** (deletion with commission debt). The debt rule is untouched. `AccountDeletionService` only gained the password check path (CR-05, in the controller) and the collision-row scrub (CR-02). |
| CR-11 | fixed | 0b12a56 | `BookingServiceImpl` | `CheckInWindowApiTest` (5) | The app still shows check-in on every accepted venue booking; outside the window it now gets a translated error. One existing test needed its booking moved near "now" (data only, no assertion changed; see "Test edits"). |
| CR-12 | not fixed | — | — | — | **Waiting for your rule** (travel-fee re-quote). Not touched. |
| CR-13 | partly fixed | 7dac156 | `BookingServiceImpl`, `BookingController`, `ServiceRequest`, `V25__service_duration_limit.sql` | `BookingRuleGapsApiTest` (9), `BookingDstNightTest` (3) | (a)–(e) fixed. (f) partly: the response window and cancellation cut-off compare instants. A waiting time written in the repeated autumn hour is still read as its first occurrence; fixing that needs the columns stored as instants. Max duration 480 min is a constant (`@Max`); the V25 CHECK is < 1440. A Book Now request accepted after its start is refused (`start_passed`) while staying PENDING until it expires: confirm this is intended. |
| CR-14 | partly fixed | 9b99b44, f76b054, 6f6cfbb | `FileStorageServiceImpl`, `application.yml`, messages | `FileStorageMetadataTest` (10), `FileStorageDecodeLimitsTest` (4) | EXIF/GPS dropped for JPEG, PNG and WebP; orientation applied; private files byte-identical. CMYK JPEGs are stored unchanged (no JDK decoder); ICC profiles are dropped. **Open P2 from the final security review**: the progressive-JPEG check can be bypassed by a junk byte in the header, so a crafted ~1–2 MB upload can make the server decode about 200 Mpx (≈116 s, ≈670 MB native memory per request). The old code never decoded, so this risk is new. See "Open items". |
| CR-15 | fixed | f7060aa | `live_booking_cubit.dart`, `tracking_page.dart`, ARB files | `sos_failures_test.dart` (4) | Not tried on a device. A failed SOS briefly shows two banners. |
| CR-16 | fixed | 9e5d5ad, 2c96974 | `live_booking_cubit.dart`, booking datasource/repository, backend `SafetyEventRequest`, `SafetyEvent`, `SafetyService`, `V26__sos_location_fix.sql` | `sos_restore_test.dart` (8), `ApiFlowIntegrationTest.sosKeepsTheFixTimeAndAccuracyAndStillAcceptsRequestsWithoutThem` | A fresh GPS fix is tried for up to 4 s before the last known one. V26 not run on PostgreSQL 16. |
| CR-17 | fixed | 64b3d44 | `booking_repository_impl.dart` (one guard for every method) | `booking_failures_test.dart` (6) | The same hole exists in the auth, provider, home, notification, review, saved and dashboard repositories. They are outside this finding and not fixed. |
| CR-18 | fixed | fc95633, c9f7e8a, 301b090 (app); 0f38c23, f853ea3 (admin) | app `auth_bloc.dart`, `api_client.dart`, `push_registrar.dart`; admin `api.js`, `App.jsx` | app `auth_session_end_test.dart`, `api_client_test` (CR-18), `push_registrar_test` (CR-18); admin `App.signout.test.jsx` (5), `api.cross-tab-refresh.test.js` (4) | Server sign-out is best effort with a 3 s limit after the local tokens are cleared, as the finding recommends. On a dead network the refresh token stays valid on the server until it expires. Two follow-up races found by the reviewers were fixed (commits f853ea3, 301b090). |
| CR-19 | fixed | d7b3910 | admin `App.jsx` | `Safety.refresh.test.jsx` (4) | Refreshes every 15 s and when the badge count changes. |
| CR-20 | fixed | 1bceba1, f1d813a, be62d65, 45ae874 | `deploy/backup/backup.sh`, `deploy/restore.sh`, `deploy/docker-compose.prod.yml`, `deploy/monitoring/alerts.yml`, `prometheus.yml`, `.env.example`, `docs/runbooks.md`, new `deploy/backup/backup_test.sh` | `deploy/backup/backup_test.sh` (27 checks) | Nothing Docker-based was run. Not verified: openssl is installed with `apk add` at run time (the image may not ship it); the busybox metrics endpoint and Prometheus target; the key bind mount; restore against live PostgreSQL. To turn on encryption, set `BACKUP_KEY_FILE`. |
| CR-21 | fixed | 1e0c7b7, 58a2ef6 | 9 backend controllers + `FreeTextBody`, admin `api.js`, 3 app datasources | `FreeTextBodiesApiTest` (7), `FreeTextBoundsApiTest` (4), admin `api.free-text-bodies.test.js` (11), app `free_text_bodies_test.dart` (7) | The old query parameter is still accepted. Fields still without a length bound, which overflow with a 500: verification reject reason / request-info message (255), safety event notes (1000), terms version. |
| CR-22 | fixed | 1f8e550, 7ad3bac | admin `App.jsx`, `src/test/setup.js` | `App.session.test.jsx` (6) | — |

## Open items for you

1. **CR-09, CR-10, CR-12**: the product rules asked for at the start.
2. **CR-14 decode P2** (final security review, `gates/ship-reverify-5.md`): the bypass is one junk byte. Suggested fix: scan the whole header for any progressive SOF marker (FF C2/C6/CA/CE before the first SOS), or read the flag from ImageIO's JPEG metadata. Add a junk-byte test, and consider lowering the progressive ceiling to ~25 Mpx. The protocol allowed one ship-gate fix round and one re-review, so this needs your go-ahead.
3. **MetricsTokenFilter** (new, outside CR-01…CR-22): it compares the raw request path, so `/api/actuator/promethe%75s` skips its token check. Only internal callers can reach it (Caddy decodes the path and answers 404). Not fixed; it is a one-line change if you want it.
4. **`identifier_collisions`**: after V19 runs in production, resolve any rows by hand.

## Chosen defaults (all in `application.yml` unless noted)

`aiwa.auth.max-failed-attempts=5`, `aiwa.auth.lockout-duration=15m`, `aiwa.auth.mfa-max-wrong-codes=5`;
`aiwa.booking.payment-dispute-window-hours=48`; `aiwa.booking.check-in-lead-minutes=30`;
`aiwa.booking.auto-dedup-window=10s`; max service duration 480 min (constant in `ServiceRequest`);
`aiwa.safety.sos-retry.*` (sweep 30 s, grace 2 min, back-off 1 min doubling to 15 min);
`aiwa.storage.public-max-image-side=2048`, `public-max-image-pixels=200000000`,
`public-max-progressive-pixels=50000000`, `public-decode-concurrency=2`, `public-decode-wait-ms=5000`;
admin `SAFETY_REFRESH_MS=15000`, `SIGN_OUT_TIMEOUT_MS=3000`; app sign-out cap 3 s, SOS fresh-fix 4 s;
backup alerts: stale after 26 h, metrics missing or unencrypted for 1 h.

## Test edits (no assertion changed in any existing test)

- `ApiFlowIntegrationTest.aReportedCommissionPaymentReachesFinanceAndClearsOnConfirm`: the request gained `expectedAmount` (CR-06 makes it required).
- `BookingPaymentAndStaffTest.customerChecksInAtVenue`: the booking start moved to now + 10 min (CR-11 window).
- app `live_booking_test`, `sos_failures_test`, `push_registrar_test`: fakes gained the new optional parameters and calls.
- admin `src/test/setup.js`: `asyncUtilTimeout: 5000`. The pre-existing ProfileView and SettlementDetail tests flaked under parallel load.
- The orchestrator waived one criterion: the U14 criterion "each new test fails before the fix". Two of its four tests guard behaviour the fix must keep, so they cannot fail before it.

## Test runs

| When | Backend (`mvn -B test`) | Flutter (`flutter test`) | Admin (`npm test` + build) |
|---|---|---|---|
| Baseline `af72941` | 211 passed | 120 passed | 70 passed, build ok |
| After P1 | 242 passed | 130 passed | 70 passed, build ok |
| After P2 backend wave | 274 passed | 130 passed | 72 passed, build ok |
| After all units, `d93ca70` (cold) | 292 passed | 166 passed | 102 passed, build ok |
| Final `f519a32` (cold, after the ship-gate fix round) | 303 passed | 166 passed | 102 passed, build ok |

`flutter analyze --no-fatal-infos` reports the same 2 info-level deprecations in the generated `lib/l10n/app_localizations.dart` at every point. They are on the baseline too and come from this Flutter version.
