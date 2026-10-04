# Fixes for the 2026-10-03 production audit (`7cf09c3`)

Branch `fix/stabilize-2026-10-04`, from `7cf09c3`. The audit report itself lives outside the repo
(`AIWA-production-audit-2026-10-03-7cf09c3.md`). One row per finding that was changed; findings
waiting for an owner rule are listed at the end.

| ID | Status | What changed | Covering tests |
|---|---|---|---|
| C-1 | fixed | `ExternalSmsService.send` throws on a transport error, a non-2xx, or a 2xx whose JSON says the text was refused (`success:false`, `ok:false`, a failure `status`, a non-empty `error`). SOS deliveries are then FAILED, retried and counted. New counter `aiwa.sms.sent{kind,result}` and alert `SmsSendFailures`. | `ExternalSmsServiceTest` (7, real class against a stub HTTP server) |
| H-1 | fixed | Suspending a provider or deactivating their account cancels their PENDING / ACCEPTED / ON_THE_WAY / ARRIVED bookings and notifies each customer (IN_PROGRESS is left to finish). A suspended or inactive provider can decline or cancel, but accept, on-the-way, arrived, start, no-show, propose-time and travel quotes answer 403 `booking.error.provider_suspended`. Admin confirm dialogs say bookings will be cancelled; the response message gives the count. | `ProviderSuspensionApiTest` (5) |
| H-2 (part) | fixed | Flat travel fee (provider and admin) capped at the existing quote cap, EGP 5,000 (was a 500 on overflow). Closure sweep, no-show contest: **owner rule needed**. | covered by the shared constant; manual |
| H-3 | fixed | The progressive-JPEG marker walk resyncs over junk bytes as libjpeg does; a second guard reads the SOF process from the decoder's own metadata. Progressive ceiling lowered to 25 Mpx (`PUBLIC_MAX_PROGRESSIVE_PIXELS`). | `FileStorageDecodeLimitsTest` (+2: junk byte, metadata guard) |
| H-4 (part) | fixed | OTP texts only to allowed country codes (`OTP_ALLOWED_COUNTRY_CODES`, default `20`) and a global budget per hour/day (`OTP_MAX_GLOBAL_SENDS_HOUR/DAY`, 1000/10000). Counters `aiwa.otp.sent`, `aiwa.otp.global_budget_exhausted`; alert `OtpGlobalBudgetExhausted`. Enforced TOTP for admins: **owner decision E-1**. | `OtpPumpingGuardTest` (4) |
| H-5 | fixed | Call / WhatsApp / Directions call `launchUrl` directly (shared `openExternal`) and show a message when nothing opens them. Android `<queries>` for tel / https / whatsapp, iOS `LSApplicationQueriesSchemes`. **Not tried on a device.** | `flutter analyze`; device check pending |
| M-1 (part) | fixed | Home-service bookings need a saved address and must be inside the provider's `serviceRadiusKm` when set; at most 5 open requests per customer (`BOOKING_MAX_OPEN_REQUESTS`). Restricting `POST /bookings` to customers and a "provider offers home visits" flag were not changed (no such flag exists). | `BookingHomeServiceTravelFeeTest` (+3) |
| M-2 | fixed | Admin flags are filed with the acting admin as reporter; `/complaints/my` never lists `ADMIN_FLAG` rows (covers flags stored the old way). | `ModerationPrivacyApiTest` |
| M-3 (part) | fixed | ID documents need SUPPORT; booking chats need SUPPORT or FINANCE (dispute evidence) and every read is audited. Admin panel hides them otherwise and the dispute chat shows load errors instead of "No messages". Contact edits, temp passwords, TOTP-at-rest: not changed. | `ModerationPrivacyApiTest`, admin `VerificationDetail.documents.test.jsx` (2) |
| M-9 (part) | fixed | Role denials answer 403 with code `auth.error.forbidden_role`; the app opens its Forbidden screen only for that code (business 403s stay inline). Security-filter 401/403 use the standard error body. `DataIntegrityViolationException` → 409, `NoSuchElementException` → 404, missing multipart part / not multipart → 400, wrong media type → 415, parameter validation → 400. Invalid status transitions answer with a message key. | `ProviderSuspensionApiTest`, app `api_client_test` (+2) |
| L-3 | fixed | Audit IP is `getRemoteAddr()` (RemoteIpValve already resolves the proxy header). | existing `AuditServiceTest` |
| L-4 | fixed | Audit writes run in `REQUIRES_NEW`. Hikari pool made configurable, default 20 (`DB_POOL_SIZE`). | existing tests |
| L-9 (part) | fixed | Service name/description ≤ 255, price ≤ 1,000,000 with 2 decimals. | manual |
| L-10 | fixed | `/admin/bookings?page=-1` clamps instead of 500. | — |
| L-11 | fixed | Chat close and SOS window use `Booking.endedAt()` (completedAt / cancelledAt / slot end), not `updatedAt`. | existing chat and SOS tests |
| L-13 | fixed | Trusted-contact numbers stored in E.164 and normalized again at SOS send time; saved addresses capped at 20. | existing tests |
| L-15 | fixed | The app never sends a token-less push DELETE (it removed every phone of the user). | app `push_registrar_test` (1 changed: it asserted the old behaviour) |
| L-16 | fixed | `android:allowBackup="false"`. | — |
| L-20 | fixed | Stale `pubspec.yaml` and `api.js` comments. | — |
| L-24 | fixed | `MetricsTokenFilter` compares the decoded path. | `MetricsEndpointTest.anEncodedPathDoesNotSkipTheToken` |
| L-25 | fixed | `aiwa-backend/docker-compose.prod.yml` removed; its guide is marked outdated. | — |
| L-26 (part) | fixed | `/provider/gallery/{id}` is 404 for an unlisted provider (owner and admins still see it). Chat-report dedupe not changed. | `ModerationPrivacyApiTest` |
| — | fixed | Mojibake in `AdminUsersController` Swagger tags. | — |

### Second round (same branch)

| ID | Status | What changed | Covering tests |
|---|---|---|---|
| AU-20 / L-23 | fixed | Providers see the customer's saved address only while the request is open or the visit is live; after reject, expiry, cancel, completion or no-show it is left out of every provider response. The customer still sees it. | `ProviderSuspensionApiTest.theProviderNoLongerSeesTheCustomersAddressOnceTheRequestEnds` |
| AU-14 / L-1 | fixed | Register proves the phone or email (OTP) before answering "already taken". | existing auth tests |
| AU-14 / L-2 | fixed | Account status is checked after the password: a wrong password on a disabled account is a plain 401. | `ModerationPrivacyApiTest` |
| AU-14 / L-6 | fixed | The `accessToken` cookie is no longer accepted; only the Bearer header. | `ModerationPrivacyApiTest` |
| AU-14 / L-7 | fixed | After a revocation could not be written to Redis, Redis misses are double-checked in the database until that token would have expired. | `TokenBlacklistServiceTest` (+2) |
| AU-13 (more) | fixed | Not-found errors answer the translated `error.not_found` (code kept); user-facing settlement, terms, missing-field and reject errors use message keys (en, ar). Admin-only messages stay English (the panel is English). | `SettlementControllerTest` (assertion now on the key) |
| AU-15 / L-14 | fixed | The app caches the signed-in user; a cold start with no network opens that account instead of the sign-in screen (tokens were always kept). | app `auth_flow_test` (+2) |
| AU-10 (part) | fixed | `GET /bookings/{id}/chat?afterId=` returns only newer messages; the app polls incrementally with an in-flight guard and reloads the full thread about once a minute. | `ProviderSuspensionApiTest.chatPollingWithAfterIdReturnsOnlyNewerMessages`, app `chat_poll_test` |
| AU-11 (part) | fixed | `.github/dependabot.yml` (Maven, npm, pub, Docker, Actions); CI fails on high/critical `npm audit` advisories; counters `aiwa.push.sent{result}` and `aiwa.auth.login{result}` with alerts `PushSendFailures` and `SignInFailureSpike`. | `npm audit` clean today |
| AU-12 (part) | fixed | Every round icon button is announced by screen readers (back, close, call, chat, send, edit, delete, share, notifications, save) in English and Arabic. | app `shared_widgets_test` (+1) |
| AU-08 (more) | fixed | Admin contact changes notify the user and the OLD phone (SMS) and email; TOTP secrets encrypted at rest when `TOTP_ENCRYPTION_KEY` is set (plain values still read; prod logs a warning without the key). | `AdminUsersControllerTest` (+2), `TotpSecretConverterTest` (4) |
| CR-14 (rest) | fixed | JPEGs the JDK can't decode (CMYK) have their EXIF/XMP/IPTC/comment segments removed; ICC and Adobe segments kept. | `FileStorageMetadataTest` (+2) |
| CR-13(f) | fixed | V27 adds `bookings.waiting_since_instant` (timestamptz); the response window uses it, so the repeated autumn hour can't expire a request early. Older rows keep the previous rule. | `BookingDstNightTest` (+1) |

### Third round: the owner’s product rules (2026-10-04, branch fix/owner-rules-2026-10-04)

| ID | Status | Rule and what changed | Covering tests |
|---|---|---|---|
| CR-09 / AU-17 | fixed | SOS for everyone: allowed up to 6 h after a booking is cancelled (as after completion); providers get the SOS section on their booking page; customers at a venue get it once the visit is in progress. | `OwnerRulesApiTest`, app analyze |
| CR-12 | fixed | A travel fee can get a first quote after acceptance but never a re-quote; accepting a quote needs the amount the customer saw (409 `quote_changed` otherwise); the app sends it. | `OwnerRulesApiTest` |
| CR-10 / M-4 | fixed | Self-service deletion is refused (409) while the user has a live booking or unpaid commission, with a message saying what to finish. Support’s admin delete is unchanged. | `OwnerRulesApiTest` |
| AU-05 | fixed | Only customer accounts create bookings (403 for providers and admins; the app routes providers to its forbidden page). | `OwnerRulesApiTest` |
| AU-07 | fixed | A provider who cancels an accepted booking is charged the penalty percent of the service price as a ledger entry; 3 penalised cancellations in 30 days pause new bookings and alert admins. | `OwnerRulesApiTest` (2) |
| AU-03 | fixed | The scheduler completes IN_PROGRESS bookings a day after the slot as cash pending with commission, and flags accepted / on-the-way / arrived ones once into the admin inbox ("Booking needs closing"). A customer can contest a no-show within 48 h (once); it opens a payment dispute and a PAID resolution completes the booking and charges commission. App: "This wasn’t a no-show" button. V28. | `OwnerRulesApiTest` (4) |
| E-1 / AU-09 | fixed | In prod, Super admin and Finance admins get 403 `auth.error.admin_2fa_required` on every `/admin/**` call until two-factor is on; the admin panel shows the setup card instead. `REQUIRE_ADMIN_2FA=false` turns it off. | `AdminTwoFactorApiTest` (3) |
| AU-18 / M-5 | fixed | Home-based (INDIVIDUAL) providers’ public pin is rounded to about 500 m, with no street address and the distance rounded to 0.5 km; the owner, admins and customers with a live booking see the exact place. Shops stay exact. | `OwnerRulesApiTest` (2) |
| AU-19 / L-22 | fixed | Terms acceptance is stored per document type (V29, existing acceptances carried over); `/auth/me` `termsUpToDate` uses the role’s main document; bookings are refused while it is out of date (`terms.error.not_accepted`). | `OwnerRulesApiTest` |

Test edits: none to existing assertions. `application-test.yml` sets `aiwa.terms.enforce-on-booking=false` (shared test contexts); `OwnerRulesApiTest` turns it on.

### Fourth round: security and quality hardening (2026-10-04, branch hardening/security-quality-2026-10-04)

| ID | Status | What changed | Covering tests |
|---|---|---|---|
| AU-08 / M-3 | fixed | The temporary password is sent to the **user** (SMS, else email) and is no longer returned to the admin; if neither channel works the reset rolls back and the old password keeps working. The admin panel shows "sent by SMS to ***1234". Support can no longer read it out to the user. | `AdminUsersControllerTest` (2), `SupportResetLiftsSignInLockApiTest` |
| AU-08 / M-3 | fixed | ID documents and selfies are encrypted at rest (AES-256-GCM) once `DOCUMENT_ENCRYPTION_KEY` is set; files written before stay readable, an encrypted file without the key fails loudly. Public photos are never encrypted. | `PrivateFileCipherTest` (4), `FileStorageServiceImplTest` |
| AU-09 / H-4 | fixed | OTP texts time out after 3 s connect / 5 s read (SOS texts keep 5 / 10 s) so a gateway outage ties up request threads for less time. | `ExternalSmsServiceTest` |
| L-8 | fixed | With Redis down, sending or checking an OTP answers 503 `otp.error.unavailable` instead of an unexplained 500. | `OtpRedisDownTest` (2) |
| L-9 (rest) | fixed | Bounds on the admin create/edit forms (names 255, phone 32, password 12 to 72), SOS coordinates and accuracy, availability slot length (5 to 240 min), reschedule reason (255), verification reject reason (255), request-info message (900) and note (2000). | `HardeningApiTest` (3) |
| L-12 | fixed | A provider can be approved only after the ID front, ID back and selfie were submitted. | `HardeningApiTest` |
| L-5 | fixed | Deleting a user takes the same row lock as deactivating, and the last active super admin can’t be deleted. The bootstrap branch of `requireSuperAdmin` stays (an existing test documents it as deliberate recovery). | `AdminUsersControllerTest` |
| L-18 | fixed | Admin accounts’ refresh tokens live 8 hours (`JWT_ADMIN_REFRESH_EXPIRATION_MS`) instead of 7 days; everyone else is unchanged. | `HardeningApiTest` |
| L-21 | fixed | The admin inbox reads at most the requested number of disputed bookings instead of loading all of them. | existing inbox tests |
| L-26 | fixed | A chat message has at most one open report; reporting it again only confirms it. | `HardeningApiTest` |
| M-8 / AU-10 | fixed | Notifications are deleted after 180 days (`NOTIFICATION_RETENTION_DAYS`, 0 = keep), nightly at 03:30. | `HardeningApiTest` |
| DB | fixed | V30: `CHECK` constraints keep service prices, booking totals and travel fees, and commission amounts from going negative (`NOT VALID`, so existing rows can’t stop the migration). | not run on PostgreSQL |
| §14 | fixed | Dead code removed: `UserRepository.findByPushToken`, `BookingRepository.findByStatusAndCreatedAtBefore`, `CommissionLedgerRepository.findAllByOrderByCreatedAtDesc`, `TokenBlacklistService.claim`. | compile |

Not done, on purpose: turning `open-in-view` off (entities are mapped lazily in many controllers and only some are covered by tests, so a missed one would be a 500 in production only; do it as its own change with an end-to-end run); discovery and sweep queries in SQL (needs a load test first); `lower(email)` unique index (fails while `identifier_collisions` rows exist; resolve them first); `users.push_token` column drop (destructive); dates with an offset (L-17); pushing OTP sends to a background thread (the user would no longer learn when it failed); L-27 push-token binding (low risk, needs an install id in the app).

### Fifth round: the system audit items SA-01 to SA-15 (2026-10-04, main)

| ID | Status | What changed | Covering tests |
|---|---|---|---|
| SA-01 | fixed | The mandatory two-factor check covers every route except `/auth/**`, `/actuator/**` and `/error`, not only `/admin/**`. A Super admin or Finance admin without two-factor can no longer publish terms or change support settings. | `AdminTwoFactorApiTest` |
| SA-02 | fixed | `POST /auth/2fa/enable` ends every session issued before it (access and refresh tokens) and returns a fresh token pair in `data`; the admin panel stores it. | `AdminTwoFactorEnrolmentApiTest`, panel `api.js` |
| SA-03 | fixed | `POST /auth/verify-otp` returns a random one-time `receipt`; `/auth/register` needs it as `verificationReceipt`. Before, any caller could register a number someone else had just verified. The app keeps the receipt and sends it. | `VerifiedEmailApiTest`, `ApiFlowIntegrationTest` |
| SA-04 | fixed | `restore.sh` test-restores the dump into a scratch database first and runs the live restore as one transaction that stops at the first error, restarting the backend if it fails; `backup.sh` verifies the dump the same way instead of only reading its table of contents. | `deploy/restore_test.sh` (real PostgreSQL, 7 checks), `backup_test.sh` (28) |
| SA-05 | partly fixed | The double hyphen in the manifest comment is gone (the manifest was invalid XML) and CI has an Android debug build job. The job has not run yet, and the Sentry Kotlin error the audit saw on a preview SDK is not isolated. | none possible without the Android SDK |
| SA-06 | fixed | A Redis write failure during a revocation is recorded in the database too (a marker row in `revoked_tokens`), so a restarted or second instance still double-checks Redis misses against the database. | `TokenBlacklistServiceTest` (2) |
| SA-07 | fixed (rule chosen) | A booking stores the commission rate in force when it was made (`commission_percent_at_booking`, V32); completion charges that rate, so a later change applies to future bookings only, as the panel says. Older bookings keep using the current rate. Cancellation-penalty rules still read the current setting. | `OwnerRulesApiTest` |
| SA-08 | fixed | The three-strike pause is its own flag (`disciplinary_hold`, V31); settling commission clears only the financial pause, and only an admin lifting the pause clears the hold. | `OwnerRulesApiTest` |
| SA-09 | fixed | The chat and review moderation resolvers answer 404 for a case of another type. | `OwnerRulesApiTest` |
| SA-10 | fixed | Booking creation takes the customer's row lock (after the provider's) before counting open requests. | `CustomerPendingCapRaceTest` (fails every time without the lock) |
| SA-11 | fixed | Support's deletion is refused (409 `admin.error.delete_live_visit`) while a visit is on the way, arrived or in progress. | `OwnerRulesApiTest` |
| SA-12 | fixed | The chat cubit keeps messages that arrived while a full load was running and never lists a message twice. | app `chat_poll_test` (2) |
| SA-13 | fixed | A failed load-more asks for the same page again; one load-more runs at a time. | app `booking_load_more_test` |
| SA-14 | fixed | The admin panel tells a refresh the server rejected (401/403) from one it could not get an answer to (network, 5xx, proxy page); the latter keeps the tokens and shows a temporary failure. | panel `api.refresh-token.test.js` (3) |
| SA-15 | fixed | The suite passes on PostgreSQL 16 with Flyway and schema validation: test pools are small (6, no idle connections), the H2-only `auto_increment` is portable, three classes no longer share a phone prefix, and `OwnerRulesApiTest` accepts the terms V13 seeds (the tests about missing acceptance are unchanged). A second run needs a fresh database, as in CI. | whole suite |

Needs doing by hand: set the two encryption keys and tell support that temporary passwords go to the user (fourth round); apps built before this round cannot register until they are updated, because register now needs the receipt.

## Test edits

- `BookingLifecycleServiceTest`: the booking fixture's provider is now APPROVED and active (data only; the H-1 guard refuses an unapproved one).
- `BookingHomeServiceTravelFeeTest`: home-service requests carry a saved address (data only; M-1).
- `VerificationRequestInfoTest`, `AdminUsersControllerTest`: constructors take the booking service.
- `SupportResetLiftsSignInLockApiTest` and `AdminUsersControllerTest.resetPassword...`: they read the temporary password from the admin’s response; they now read it from the message sent to the user, and assert the response doesn’t contain it (AU-08).
- App `push_registrar_test`: "sign-out clears the token" asserted the L-15 bug (a token-less DELETE); it now asserts nothing is sent. The CR-18 test got a token source.
- `SettlementControllerTest.payingWithNoDuesFails`: asserts the message key instead of the English sentence (AU-13).
- `ChatControllerModerationTest`: passes `afterId = null` to the new parameter.

## Cleanup (Cleanup tab of the tracker, 2026-10-04, branch cleanup/remove-dead-abstractions-2026-10-04)

| Item | Status | What changed |
|---|---|---|
| App: 19 use cases (`domain/usecases/`) | done | Every one only forwarded a call to a repository with the same signature and defaults. Deleted; the blocs and the four widgets that resolved a use case from get_it now call the repository. DI registrations removed. 9 test files build the blocs with the repository. |
| App: field-by-field `PagedData` copies | done | 4 copies replaced with `return Right(result);` (home x2, notifications, saved). The bookings one filters, so it stays. |
| Backend: six single-implementation service interfaces | done | `AuthService`, `AvailabilityService`, `BookingService`, `ProviderService`, `ReviewService`, `ServiceManagementService` deleted; the `*Impl` classes stay and are injected directly (`Email`, `Sms` and `Push` keep their interfaces: they have real second implementations). |
| App: repository interfaces with one `*Impl` | not done, on purpose | Every bloc test fakes a repository through the interface (`implements BookingRepository` and the like), so removing them would mean rewriting those fakes for no behaviour change. Revisit only if the tests move to a mocking library. |
| App: `dartz` `Either` to a sealed `Result` | not done, on purpose | Touches every repository, bloc and test; no bug or size win to justify it now. |

Tests after the cleanup: backend 359, Flutter 172 (analyze clean). No assertion changed; the tests only construct the blocs differently.

## Not changed: needs an owner rule or a device

Settled by the owner on 2026-10-04 and implemented in the third round: CR-09, CR-10, CR-12, AU-03, AU-05,
AU-07, AU-17, AU-18, AU-19, E-1. Still open: L-17 (dates with an offset: every DTO and both clients), H-5 and M-13
(real phones), M-8 load test, M-12 off-site backups and a restore drill (infrastructure), M-3 leftovers (temporary
password shown to the admin, ID documents unencrypted on disk), OTP sent off the request thread.

## Test runs

| When | Backend (`mvn -o test`) | Flutter (`flutter test`) | Admin (`vitest` + build) |
|---|---|---|---|
| Baseline `7cf09c3` | 303 passed | 166 passed, analyze clean | 102 passed, build ok |
| First round `029195f` | 328 passed | 168 passed, analyze clean | 104 passed, build ok |
| Second round | 343 passed | 172 passed, analyze clean | 104 passed, build ok |
| Third round | 359 passed | 172 passed, analyze clean | 104 passed, build ok |
| Fourth round | 375 passed | 172 passed (unchanged), analyze clean | 104 passed, build ok (in a Linux container) |
| Fifth round | 384 passed on H2, 383 on PostgreSQL 16 | 175 passed, analyze clean | 107 passed, build ok (in a Linux container) |
