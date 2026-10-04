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

## Test edits

- `BookingLifecycleServiceTest`: the booking fixture's provider is now APPROVED and active (data only; the H-1 guard refuses an unapproved one).
- `BookingHomeServiceTravelFeeTest`: home-service requests carry a saved address (data only; M-1).
- `VerificationRequestInfoTest`, `AdminUsersControllerTest`: constructors take the booking service.
- App `push_registrar_test`: "sign-out clears the token" asserted the L-15 bug (a token-less DELETE); it now asserts nothing is sent. The CR-18 test got a token source.
- `SettlementControllerTest.payingWithNoDuesFails`: asserts the message key instead of the English sentence (AU-13).
- `ChatControllerModerationTest`: passes `afterId = null` to the new parameter.

## Not changed: needs an owner rule or a device

CR-09 / M-6 (who may raise SOS), CR-10 / M-4 (deletion with debt or live bookings), CR-12 (travel re-quote),
E-1 (enforce admin TOTP), H-2 closure sweep and no-show contest, M-5 (round home-based providers' location),
M-7 (penalties and strikes), L-22 (per-type terms acceptance), M-1 (bookings by customers only). L-17 (dates
with an offset) changes every DTO and both clients. H-5 and M-13 need real phones. M-8 load test, M-12 off-site backups and a restore drill
need infrastructure.

## Test runs

| When | Backend (`mvn -o test`) | Flutter (`flutter test`) | Admin (`vitest` + build) |
|---|---|---|---|
| Baseline `7cf09c3` | 303 passed | 166 passed, analyze clean | 102 passed, build ok |
| First round `029195f` | 328 passed | 168 passed, analyze clean | 104 passed, build ok |
| Second round | 343 passed | 172 passed, analyze clean | 104 passed, build ok |
