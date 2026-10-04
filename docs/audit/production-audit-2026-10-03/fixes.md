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

## Test edits

- `BookingLifecycleServiceTest`: the booking fixture's provider is now APPROVED and active (data only; the H-1 guard refuses an unapproved one).
- `BookingHomeServiceTravelFeeTest`: home-service requests carry a saved address (data only; M-1).
- `VerificationRequestInfoTest`, `AdminUsersControllerTest`: constructors take the booking service.
- App `push_registrar_test`: "sign-out clears the token" asserted the L-15 bug (a token-less DELETE); it now asserts nothing is sent. The CR-18 test got a token source.

## Not changed: needs an owner rule or a device

CR-09 / M-6 (who may raise SOS), CR-10 / M-4 (deletion with debt or live bookings), CR-12 (travel re-quote),
E-1 (enforce admin TOTP), H-2 closure sweep and no-show contest, M-5 (round home-based providers' location),
M-7 (penalties and strikes), L-22 (per-type terms acceptance). L-14 (offline cold start) needs a cached-user
state in the router. H-5 and M-13 need real phones. M-8 load test, M-12 off-site backups and a restore drill
need infrastructure.

## Test runs

| When | Backend (`mvn -o test`) | Flutter (`flutter test`) | Admin (`vitest` + build) |
|---|---|---|---|
| Baseline `7cf09c3` | 303 passed | 166 passed, analyze clean | 102 passed, build ok |
| End of this branch | 328 passed | 168 passed, analyze clean | 104 passed, build ok |
