# Prompts: build what's missing from the AIWA prototype

Run one phase per fresh LLM session, in order. Each phase reads only its own brief file (5–14k tokens), so a small context window is enough. Paste the **shared preamble** first, then that phase's prompt.

When a phase is done, commit it before starting the next. Later phases assume earlier ones landed (phase 0 creates the Toast, SystemScreen and other shared widgets that every later phase reuses).

---

## Shared preamble (paste at the top of every phase)

```text
You are a senior Flutter engineer working in the AIWA repo.

Project layout
- Flutter app: Android/aiwa_app/ (go_router in lib/core/router/app_router.dart, theme in lib/core/theme/, shared widgets in lib/shared/widgets/, features in lib/features/<feature>/{data,domain,presentation}; state = flutter_bloc, DI = get_it in lib/core/di/injection_container.dart, HTTP = dio via lib/core/network/api_client.dart).
- Backend (Spring Boot, source of truth for API contracts): aiwa-backend/src/main/java/com/aiwa/ (controllers in controller/, request/response DTOs in dto/).
- Design prototype (source of truth for UI): C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/ui_kits/aiwa-app/*.jsx. Colors come from the global `aiwa` object; theme.jsx applies MALE_THEME at load (charcoal #2E2A26 / stone #B5A898 / off-white #F5F2ED) and FEMALE_THEME after a female gender pick (mauve #6B3A3A / dusty rose #C4837A / blush #FDF6F4). Flutter already mirrors both palettes in AppColors (gender-aware getters) — always use AppColors / AppTextStyles / AppTheme tokens, never raw hex.

Working rules
- Your task list is the brief file named below. Each entry quotes the prototype (file:line), the current Flutter code (file:line) and a suggested fix. Open the cited prototype lines before building a screen so copy, spacing, radii and colors match exactly.
- Before writing a widget, check lib/shared/widgets/ for an existing one (AiwaButton, AiwaChip, AiwaTextField, ConfirmSheet, EmptyState, ScreenChrome, StatusPill, EyebrowLabel, etc.) and reuse it.
- For any data the screen needs, read the backend controller + DTO first and match field names exactly. If the backend has no endpoint for something, build the UI against a repository method that returns a clear "not supported yet" failure and list the gap in your final summary — do not invent endpoints.
- Wire every new screen into app_router.dart and into the navigation the prototype uses (what pushes it, what it pushes, what back does).
- Copy text verbatim from the prototype. Icons: use the Lucide equivalent if lucide icons are installed, otherwise the closest Material icon.
- No spinners: loading states use the existing shimmer/pulse widgets.
- Keep changes scoped to this phase. Don't refactor unrelated code.
- After changes: run `flutter analyze` and `flutter test` from Android/aiwa_app and fix what you broke.
- Finish with a short summary: entry IDs done, entry IDs skipped and why, backend gaps found.
```

---

## Phase 0 — Foundation

```text
Brief: docs/fidelity-phases/phase-0-foundation.md

Build the shared layer every later phase depends on:
1. ApiClient: exceptions thrown inside the Dio interceptor are re-wrapped as DioException, so repositories' ServerException/UnauthorizedException/NetworkException catches never fire. Unwrap them (see the fix in ACCT-C07 / the brief) so callers get the real exception.
2. Global HTTP-status routing: 401 (refresh rejected) -> Session expired, 423 -> Account locked, 403 -> Forbidden, 404 on a deep link -> Not found. Build the shared SystemScreen shell (ONB-04) and these four screens (ACCT-24..27) on top of it.
3. Missing shared primitives: Toast (top of screen, success check, replaces SnackBars — make a single `showAiwaToast(context, message)` helper), OfflineBanner driven by connectivity_plus (ACCT-31 / DS-20), Toggle, SuccessSheet, Pagination/EndOfList, SkeletonRows.
4. Navigation chrome: modal sheets must open on the root navigator so the tab bar sits under the barrier; push/pop transition = 320ms slide 8% with Curves easeSoft (cubic 0.32,0.72,0,1), tab switches = fade/scale per the brief; remove RefreshIndicator spinners.
5. GuestLockedView CTA must go to the auth gate, not role choice (DS-36-F1).
Also fix the other critical/major entries listed in the brief (fonts bundled offline, logo assets + launcher icon, etc.).
Do not build feature screens yet.
```

## Phase 1 — API contract

```text
Brief: docs/fidelity-phases/phase-1-api-contract.md

Every finding in this brief is a Flutter data-layer call that doesn't match the backend (wrong field names, wrong endpoint, body vs query param, keys the backend never sends). For each: open the backend controller + DTO, then fix the Flutter datasource, model (fromJson/toJson), repository and entity so they match. Examples: booking create must send bookingDate/startTime (not scheduledDate/scheduledTime); provider decline must send `reason` as a query parameter; provider stats must use /provider/dashboard; saved-provider and reviews endpoints must match the real routes.
Add or update unit tests for each changed model's fromJson with a JSON sample copied from the backend DTO.
No UI work in this phase beyond what's needed for screens to display the corrected data.
```

## Phase 2 — Sign-in / sign-up

```text
Brief: docs/fidelity-phases/phase-2-auth.md

Fix the critical/major auth issues and build the missing auth screens:
- Forgot password: 3 steps (identifier -> OTP -> new password) + toast 'Password reset. Please sign in.' (AUTH-20..23). Read AUTH-21-V1: don't call /auth/verify-otp at step 2 if that consumes the code needed at step 3 — check the backend reset flow.
- Wrong-password error box, email sign-up OTP step, Resend not pushing a duplicate OTP page (pages must stop reacting to the shared AuthBloc when not on top — AUTH-CF-03), provider sign-in routed to the pending gate, splash choices shown even if the session check fails.
- AvatarGender: photo upload (AUTH-18), preselect Woman, fix the 'Man' swatch to #B5A898, and after Continue go to Terms (phase 3 builds Terms/Preferences; for now route to a placeholder route name `/terms` that phase 3 will implement — register the route).
- 'Welcome back, {name}.' toast on sign-in using the phase-0 Toast.
```

## Phase 3 — Onboarding tail

```text
Brief: docs/fidelity-phases/phase-3-onboarding.md

Build the onboarding sequence the prototype uses after Avatar/gender:
Terms (with agree checkbox gating) -> Preferences (area, min/max radius pair, language pills EN/العربية, theme commit) -> Permission priming: location -> notifications -> Home.
Providers: Business info -> Verification -> Terms -> Preferences -> Pending (+ toast 'Account created. Verification in review.').
Also: permission priming variants for camera and contacts, Terms re-accept screen (reached from a terms-update notification) + toast 'Thanks — terms accepted.'.
Account creation must happen at the point the backend expects — read the brief's findings (ONB-01-F1, ONB-17-F1) and move the register call so Terms acceptance/version is sent with it.
Provider onboarding must actually send the business profile and upload ID/selfie (ONB-12-F1, ONB-15-F1, ONB-17-F2) using image_picker.
Declare the Android/iOS permissions (location, camera, notifications, contacts) in the manifests.
```

## Phase 4 — Customer discovery

```text
Brief: docs/fidelity-phases/phase-4-discovery.md

Build: FlagProviderSheet (+ Report chip on the provider profile, + toast), StaffPickerScreen for shop-type providers.
Fix routing: Book on provider profile -> staff picker (shop) -> auth gate (guest) -> booking type (phase 5a builds booking type; register a `/booking-type` route now). Auth gate must resume the booking after sign-in. Saved 'Book again' -> provider profile.
Then the major findings: Open-now status, 'From EGP' price, Discover query+category combined, price sort/filter, empty-state actions, home category grid overflow on 360dp, Bookings tab badge, share button.
```

## Phase 5a — Booking creation

```text
Brief: docs/fidelity-phases/phase-5a-booking-create.md

Build: Booking type screen (Now vs Later), Book Now availability check sheet with its states (checking, OFFLINE, BUSY, VACATION, SETTLEMENT_PAUSED), Booking screen Book Now variant, home-vs-salon toggle, saved address selector (Home/Work/Add new — the address form itself is phase 6; link to its route), Slot conflict sheet (409) with alternatives + toast 'Rebooked for {time}.', toasts 'Booking placed. Waiting to confirm.' / 'Provider is on the way.'.
Fix: slot grid source (BOOK-08-V1 if not already done in phase 1), Confirmed -> 'View my bookings' goes to Tracking.
```

## Phase 5b — Live booking

```text
Brief: docs/fidelity-phases/phase-5b-booking-live.md

Build the Tracking screen as one screen driven by booking status (pending, accepted, on the way, arrived, in progress, completed), with: provider contact card, home-service safety card + 3-stage SOS, venue check-in card (branch on location home vs venue), travel-fee quote accept/decline.
Build: Chat (masked number) + report-message sheet, Payment confirm (customer: paid / unpaid-dispute) + toasts, Proposed time (accept/decline, countdown, expired), Rejected (reason + alternatives), Expired booking, Complaint + toast, Cancel sheet with reasons (+ 'Something else' note).
Fix the bookings list: cards open Tracking / Rejected / Expired by status, 'Track' button, guest CTA -> auth gate.
If the backend lacks something (live location stream, masked-number proxy, chat presence), build the UI with a clearly marked stub in the repository and list it as a backend gap.
```

## Phase 6 — Account

```text
Brief: docs/fidelity-phases/phase-6-account.md

Profile tab: all 10 rows from the prototype with their destinations. Build: Personal info (edit, validation, saving state, toast), Saved addresses list + add/edit form (map pin, building/floor/apt, landmark, notes, default) + delete confirm + toasts, Safety & policies (accordion), Trusted contacts (list, empty, inline add, remove confirm), Notification preferences (channel toggles, quiet hours), WhatsApp support + toast, Delete account sheet (type DELETE) + toast -> splash, Permission-denied screens (location, camera, notifications) with their fallbacks.
Notifications inbox: rows must route (booking -> Tracking, terms update -> Terms re-accept) and unread styling must clear.
```

## Phase 7a — Provider core

```text
Brief: docs/fidelity-phases/phase-7a-provider-core.md

Replace the single /provider-dashboard page with a provider shell: ProviderTabBar (Today / Bookings / Services / Schedule / Profile) using a StatefulShellRoute. Today: stats, new requests (cards tappable), confirmed today (+ empty state). Bookings: Pending/Upcoming/Past tabs that really filter (client-side if the backend ignores status). Booking detail: review & respond, propose another time + toast, quote travel fee sheet + state banners, cancel-after-accept penalty sheet + toast, 'Mark completed' -> Payment confirm (provider: cash received / dispute + toast) -> Rate customer -> toast 'Rating submitted. Slot freed — next booking notified.'. Provider notifications inbox reachable from Profile. Unapproved providers must land on Pending (PROV-02-F1).
Services / Schedule / Profile tabs can be simple placeholders registered in the shell — phase 7b fills them.
```

## Phase 7b — Provider management

```text
Brief: docs/fidelity-phases/phase-7b-provider-manage.md

Fill the provider tabs and sub-screens: Services, Schedule (weekly availability + travel-buffer stepper), Profile (vacation/offline toggle, verified banner, rows, sign-out confirm + toast), Wallet (ledger, settlement status, blocked-over-limit state), Business info (validation, re-review notice, save toast), Gallery manager (grid, cover badge, upload progress with cancel, moderation-hidden overlay, delete confirm, empty state), Reviews (distribution, filters incl. Needs reply, reply composer with char count, filter empty state), Staff & availability (shop plan).
```

## Phase 8 — Polish (one session per file)

```text
Brief: docs/fidelity-phases/phase-8-polish-<area>.md   (areas: ds, auth, onb, disc, book, acct, prov)

These are minor findings: spacing, radii, copy, icon glyphs, shadows, press feedback. Work through them in order. Each quotes the exact prototype value and the Flutter line to change. Batch edits per file. Skip any finding whose Flutter line no longer exists (earlier phases may have rewritten it) and list those in your summary.
```

---

**Not covered by these prompts:** the admin web panel (46 entries). The handoff README says it can be a separate web app (React/Vue), and the backend already has most admin endpoints. Details are in `prototype-fidelity-audit.md` §6, "Admin web panel".
