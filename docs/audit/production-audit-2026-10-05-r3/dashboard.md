Audit appendix: admin source reviewed at 2bceba5 and unchanged at ac67446. Current backend mapping lines are in api-inventory.md; the main report supersedes historical status and gives final validation results.

# Admin dashboard deep audit — 2026-10-05

Scope: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated`, against repository HEAD `2bceba560eec7c47cc5a20d707795f88af7cb789`. Read HANDOFF.md first. Historical findings are not automatically carried forward. This is a read-only audit; no application source, project dependency, lock, configuration, or repository documentation was modified. Notes live only in this audit workspace. Parent owns full snapshot test/build execution.

Evidence labels: CONFIRMED means the current source/contract determines the behavior; micro-reproduction means the exact relevant JavaScript function was executed with synthetic dependencies using bundled Node v24.19.0. Such checks are not browser or integration validation. LIKELY/POTENTIAL cases are separately identified. No secrets were read or emitted. No live provider, finance, user, or production mutation was performed.

## Findings

### AD-01 — Medium — CONFIRMED: review CSV allows spreadsheet formulas from user content

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:3412`, function `downloadCsv`, especially 3413–3417. Consumer: `Reviews.exportCsv` at 3494–3500. DTO source: `src\api.js:786` `normalizeReview` and 797 `normalizeReviewReport` pass user names/comments unchanged.
- Cause/impact: CSV escaping only doubles quotes and wraps comma/newline fields. It does not neutralize leading `=`, `+`, `-`, `@`, tabs, or carriage returns. An authenticated customer/provider can place a spreadsheet formula in a review or name. Staff exporting either reviews queue opens that formula in a spreadsheet; CSV quoting does not make a formula literal. External-link/data-retrieval behavior depends on the spreadsheet and its policy, so OS code execution is not claimed.
- Reproduce: create/display a review whose comment is `=1+1`, open Reviews > All > Export CSV, inspect its Comment cell or import into a spreadsheet. Exact extracted-function micro-reproduction produced `Comment\n=1+1`.
- Fix: apply a shared formula-neutralization policy before normal CSV quoting (including leading whitespace/control characters), explicitly encode all exports, and add a regression test capturing the generated Blob for hostile names/comments. Backend export protections do not cover this browser-generated export.

### AD-02 — Medium — CONFIRMED, micro-reproduced: policy tab responses can publish the wrong policy body

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:4626`, `TermsEditorPanel.load`; effect at 4642, selected type button 4681, publishing at 4658–4671.
- Cause/impact: customer and provider loads update shared `versions`, `draft`, `draftAr`, and `nextVersion` without cancellation/request identity. If an older request resolves after a tab switch, the current provider tab holds customer text/version, or vice versa. `publish` combines the current selected `type` with that stale text. A super admin can publish another audience's terms and trigger acceptance for the wrong body.
- Reproduce: delay GET `/terms?type=CUSTOMER_TERMS`, switch to Provider terms, resolve the provider request, then resolve the delayed customer request. Selected tab remains Provider terms while text/history/version become customer values. Save or Publish targets PROVIDER_TERMS. Exact load-function micro-reproduction: selectedType `PROVIDER_TERMS`, draftNow `Customer policy`.
- Fix: tie each load/result to its policy type and generation, cancel/ignore superseded results, key editor state per type, and disable publish while the selected type is loading or mismatched. Preserve unsaved drafts when switching tabs rather than silently overwriting them. Add delayed-response UI and publish-payload tests.

### AD-03 — Medium — CONFIRMED: confirming one payout masks the valid remaining balance

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:4341`, `SettlementDetail.confirmPayout` sets `paidOut=true`; 4376 computes `settled=paidOut || ...`; 4435–4439 replaces the confirmation action with “Settlement confirmed”.
- Backend contract: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SettlementController.java:170` `payoutEntries` deliberately limits a reported payment to its frozen entries; 219–236 `confirmPayout` leaves later entries outstanding and returns fresh `providerDetail`.
- Impact: after confirming EGP 128.40 from a total of EGP 173.40, the remaining EGP 45 is shown alongside a Settled badge/Settlement confirmed message and no further payout button. `paidOut` never resets during detail reloads. Leaving and re-entering the detail remounts state and recovers the action; backend accounting is not corrupted by this UI bug.
- Reproduce: use the already-existing fixture in `src\test\SettlementDetail.payout.test.jsx` (it explicitly models EGP 45 recorded after a report); return fresh detail with totalOwed=45, confirm EGP128.40, assert that the page still offers Confirm payout received and is not globally marked settled. Current tests stop at the amount sent and miss this.
- Fix: remove the optimistic permanent latch; derive settlement state from the successful response/fresh total/status. Show “reported payment confirmed, EGP45 remains” where appropriate. Test partial report settlement and new entries after confirmation.

### AD-04 — Medium — CONFIRMED: idle timeout does not reliably lock the dashboard; export/document helpers bypass it

- Locations: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\api.js:193` `request` clears local tokens only at 195; 313 `verificationDocUrl` and 524 `downloadFile` perform their own fetches without the idle test. App session is separate at `src\App.jsx:370`; inbox poll failures are swallowed in `useNavBadges` 646 and `NotificationBell.fetchItems` 730. No App idle timer or session-end subscriber exists.
- Impact: on static Users/Bookings/Verifications/profile/settings pages, the background inbox poll can clear credentials after 30 minutes, then swallow the 401, leaving the signed-in chrome and already-loaded PII/documents visible indefinitely. Only another load/action that calls an auth-expiry handler switches to login. If an export or private document fetch runs before a background poll enforces idle expiry (e.g. throttled/offline/resumed tab), it still sends the old bearer; a fresh/reloaded expired access token can also refresh through the still-live cookie because this path has not cleared the hint.
- Reproduce: load a user detail, leave idle beyond 30 minutes, let inbox poll 401; verify the old profile remains on screen. Exact API micro-reproduction set synthetic access plus last_activity 45 minutes ago and called `api.exportAudit`: `idleExpired=true`, `authenticatedExportSent=true`, `sessionRemains=true`.
- Fix: centralize JSON/blob/export authenticated fetches behind the same idle, generation, refresh, terminal-401, and MFA handling; send App a session-ended event and lock/unmount sensitive views when timeout occurs. Use a timer/visibility-resume check and best-effort cookie logout. Tests should cover the rendered App and blob/export helpers, not just `api.me`.
- Existing idle unit tests prove only the JSON request clears credentials; they do not prove the UI is locked. This finding is independent of the now-fixed historical localStorage-token exposure.

### AD-05 — High — CONFIRMED source behavior, browser/runtime-unverified: SOS monitoring silently stops being current

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:3615`, `SafetyQueue.refresh`, catch 3617; inbox error handling at 646 and 730. Initial useLoad reports errors, but periodic quiet refresh does not update its error/loading state for any failure except final 401.
- Impact: after an initially successful empty/partial SOS load, sustained network/5xx failures leave “No open SOS alerts” or old incidents on screen without stale/offline warning or last successful sync time. New emergencies cannot be delivered to this panel, yet it continues to indicate a clear/current queue. Existing on-call SMS mitigates but does not establish UI freshness; this is not proof that real SMS sends fail.
- Reproduce: initial GET safety OPEN returns []; reject subsequent 15-second polls with a network error or 503; create an SOS elsewhere. Current panel continues to say No open SOS alerts. The existing refresh tests only exercise successful polls and stop-on-unmount.
- Fix: keep last-good rows but display a persistent stale/connection-failed banner and last-success time on any failed poll; restore healthy state on success; bound overlapping/hung polls, back off sensibly, and test outage/recovery. Monitor notification poll failures too.

### AD-06 — Medium — CONFIRMED: global Refresh acknowledges a refresh without refreshing several pages

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:882`, `RefreshButton.handleClick` broadcasts and immediately toasts “Refreshed”; listeners are only explicit callers or `useLoad` (5094). Custom loads `Verifications` 1171–1189, `Settlements` 3947–3963, `AuditLog` 4496–4514, `SettlementDetail` 4303–4311, and settings/profile loads do not subscribe. `UsersPage`, `Bookings`, `Dashboard`, shared useLoad queues, and inbox do subscribe.
- Impact: clicking Refresh while reviewing Verifications, Settlements, or Audit log fetches only other subscribers such as inbox and leaves the current list/count/history unchanged; the success message is misleading. The verification detail can continue presenting a stale decision after another admin changes the provider.
- Reproduce: render Verifications; change the mocked server list/count; click top-bar Refresh and inspect calls. Neither verification loader nor count loader reruns. Equivalent settlement/audit test reproduces. Re-entering page or a local action/retry may trigger a load.
- Fix: use a shared refresh generation in every screen loader, including detail/settings loads, and only report success when relevant refresh work succeeds. Add one page-level test per custom loader family.

### AD-07 — Medium — CONFIRMED: flag warnings/suspensions can succeed while failed resolution is concealed

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:1795`, `Flags.doWarn`; first mutation 1798 then `resolveComplaint(...).catch(() => {})` at 1801 and row removal 1802. Same sequence in `doSuspend` at 1821–1831.
- Impact: warning/suspension is sent and success is shown; if the following complaint resolution fails, the unresolved flag is still removed locally. It reappears later, inviting another warning/action. In addition, `runAction` starts a global list refresh before resolution, so a list response from between the two writes can repopulate the flag after local removal even on a successful resolution. Backend state changes remain separate transactions.
- Reproduce: mock warnUser/suspendProvider success then resolveComplaint 500. Current UI hides the flag and does not tell staff that closing the complaint failed. Slow the triggered GET flags until after local removal to expose stale re-insertion.
- Fix: provide an atomic server flag-action operation, or expose partial completion explicitly, retain/mark the unresolved row, retry only the failed closure, and trigger refresh after both operations succeed. Test first-write success/second-write failure and delayed list responses.

### AD-08 — Low — CONFIRMED: current server permission changes are not fully reflected by navigation/actions

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:126`, `NAV_REQUIRES`, covers only bookings/settlements/audit. Finance-only users are still offered Verifications, Complaints, and Photo moderation even though their GETs require SUPPORT: backend `VerificationController.java:94/104`, `ComplaintController.java:63`, `ModerationController.java:35`. Users GETs now require SUPPORT_OR_FINANCE (`AdminUsersController.java:47/122/132`) but no-permission admin nav still offers Users; `navPermissions.test.js:24` enforces the outdated “never hides other screens” assumption.
- Target-specific mismatch: `UsersPage` action menu 2169 and `ProfileView` account actions 2616 gate all ADMIN-target deactivation/reactivation only by SUPPORT. Backend `AdminUsersController.java:216/257` additionally requires SUPER_ADMIN for ADMIN targets. Support can still edit contact inputs at 2966–2967 though contact changes require SUPER_ADMIN at backend 363–367. The backend denies these requests, so this is a usability/contract issue, not a bypass.
- Reproduce: sign in Finance only and open Verifications/Complaints/Photo moderation ->403; sign in Support only and try suspending another admin or changing a customer's email ->server denial.
- Fix: define current read/action capability matrix, gate navigation and dashboard/inbox links too, hide/disable contact fields for Support, target-specific admin controls, and align test expectations. Permissionless self profile also requires the now-restricted user-detail endpoint; use auth/me for self-profile retrieval where intended.

### AD-09 — Medium — CONFIRMED: all-reviews normalization discards the server's hidden state

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\api.js:786`, `normalizeReview`, especially 793 `status: item.status || "VISIBLE"`. Backend `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminController.java:174/219` includes all reviews and serializes `.hidden(r.isHidden())` at 228; `ApiResponse.ReviewDto` uses `hidden` at `ApiResponse.java:352` and has no status property.
- Impact: All/Low rating lists display hidden reviews as visible; Hide review is offered again. Hiding a plain review removes it locally, then the global refresh returns the hidden review and it reappears without a hidden marker. This contradicts the action feedback and staff cannot distinguish hidden from public reviews.
- Reproduce: return an admin ReviewDto with `hidden:true` and no status, open All. It renders as VISIBLE and retains Hide review. Hide an existing row and allow the refresh GET to complete; row reappears similarly.
- Fix: preserve `hidden` in normalizer, derive display status from it, show a Hidden marker and appropriate restore/disabled control, and test real backend DTO shapes for list-after-hide.

### AD-10 — Low — CONFIRMED: settlement detail retry cannot clear its error

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:4303`, `SettlementDetail` load effect sets loading but never `setError("")`; success 4307 sets detail only. Rendering 4384–4385 keeps successful detail hidden while error remains.
- Impact/reproduce: initial detail GET503 ->error; click Try again ->GET200 but prior error is still displayed, detail remains hidden. Only remount recovers. A later successful local refresh likewise leaves old error latched.
- Fix: clear error when loading/when success arrives and test failure ->retry success.

### AD-11 — Medium — CONFIRMED source accessibility defect; assistive-technology/runtime-unverified

- Locations: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:3222`, Bookings interactive row is a div with onClick and no button/tabIndex/key handler; all detail/chat/cancel/dispute actions appear only inside that expanded row at 3234–3270. Keyboard-only users cannot open it. Modal focus handling: ConfirmHost at 167–193 declares alertdialog but has no aria-labelledby/description, focus trap/restore, Escape listener, or inert background; EditUserModal 2960 and AddAdminModal 4991 lack dialog semantics; DocumentLightbox 1345 lacks dialog naming/focus management. Forms otherwise use many real labels and buttons.
- Impact/reproduce: Tab through Bookings to try opening a booking; no keyboard stop/activation exists for rows. Open a confirmation dialog then Tab past buttons: focus can enter background actions; screen readers lack a programmatic dialog name.
- Fix: semantic expandable row button with aria-expanded/controls, a shared accessible modal with labelled dialog, focus trap/restore, Escape and background inert handling; add keyboard tests and an accessibility/browser check. CSS has visible focus and reduced-motion helpers, but those do not fix missing semantics.

### AD-12 — Medium — CONFIRMED contract/documentation gap: escalation email does not receive the promised incidents

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\App.jsx:4860`, SupportSettingsPanel says “The escalation email receives SOS incidents and payment disputes.”
- Current backend evidence: repository-wide `getSupportEmail|supportEmail|support.email` search yields DTO/request/entity/seeder/SupportController save-read only; `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SupportController.java:82/174` stores and returns it. There is no safety/payment notification consumer of this field. Actual incident routing uses safety/on-call SMS and notification paths; supportEmail has no delivery consumer.
- Impact/reproduce: set escalation email, raise SOS/payment dispute in a provider sandbox; no code routes such an email to this address. Staff can wrongly rely on a channel the UI claims is operational. No real incident send was performed during this audit.
- Fix: implement reliable incident/dispute delivery with retries and observable status to this configured address, or accurately label it as a published support contact and document the actual on-call routes. Add configured-recipient integration tests.

### AD-13 — Low — CONFIRMED, micro-reproduced: all-pages helper silently truncates large queues

- Location: `D:\AIWA PROJECT\AIWA\aiwa-admin-dashboard-updated\src\api.js:251`, `requestAllPages`, hard loop cap 50 (255) returns results without a truncation flag (262).
- Impact: sizes 200 cap queues at10,000; SOS size100 caps at5,000. Because screens filter and count only the returned array, they present partial totals/exports as complete and records beyond the cap cannot be searched. The 50-page safety cap is reasonable as a guard, but the silent success is not. No current production queue volume was inspected.
- Reproduce: exact helper with51 pages x200 returns50 requests and10,000 rows for server total10,200. Existing tests only cover three pages and one page.
- Fix: server-side paging/search for each queue, or expose hasMore/truncated and an actionable continuation. Do not automatically fetch unbounded queues. Also prefer authoritative totalPages over items.length<size where backend may legitimately omit orphaned reported targets (`ReviewController.java:101`, `ChatController.java:145`), though orphan occurrence is POTENTIAL and not demonstrated in current data.

## Other potential/runtime checks — not promoted to confirmed vulnerabilities

- LIKELY delayed logout/login cookie race: client `api.js:118` signOut clears memory immediately then does asynchronous best-effort POST logout; Login becomes available immediately. Backend AuthController.java:171 always clears the admin cookie in the logout response. A logout response arriving after a fresh login Set-Cookie can remove the newer refresh cookie, causing failed reload/refresh. Reproduce requires deliberate network scheduling in a real cookie-bearing browser. No credential theft/authorization bypass is claimed.
- POTENTIAL successful responses crossing a different-session storage event: generation protects refresh and retry but not successful responses at api.js:239; custom page loaders do not unmount/reset when a different admin logs in another tab. Check whether an old privileged request can hydrate PII into the current lower-permission session after tab identity changes. Backend per-request authorization still protects new requests.
- POTENTIAL build guard gap: Dockerfile demands VITE_API_BASE_URL but does not assert HTTPS or VITE_USE_MOCKS=false. .dockerignore excludes .env.local variants, not plain .env/.env.production, which Vite may read. No current mock-enabled production artifact was demonstrated. Standalone npm build still defaults API to localhost if no env; deployment must supply correct URL/CSP origin.
- Private document URLs are normally revoked on component cleanup, but a fetch completing after cleanup assigns a new blob URL without revoking it (`DocumentCard` 1308–1310). This leaks transient memory; no displayed unauthenticated document access was proven. Add cleanup for late completion if desired.

## Consumer/backend endpoint and permission map

All paths below are relative to `/api`. S=SUPPORT, F=FINANCE, A=SUPER_ADMIN (implies S/F), Any=ADMIN role. Every admin's non-auth calls require configured/enrolled 2FA in prod through AdminTwoFactorInterceptor. Server controls are authoritative.

| Consumer | Endpoints | Current server permission/contract |
|---|---|---|
| LoginScreen, App, TOTP | POST auth/login, auth/2fa/verify; GET auth/me; POST auth/refresh/logout; GET auth/2fa/status/server-time; POST auth/2fa/setup/enable/disable | Purpose-specific auth/MFA; cookie refresh X-Requested-With required; auth endpoints exempt from admin-enrollment interceptor |
| Dashboard | GET admin/dashboard; GET admin/analytics/bookings?days; GET admin/audit?page=0&size=6; GET admin/analytics/export?days | Any metrics; audit A; export S/F. Dashboard silently attempts audit for all admins and shows empty activity on403 |
| Sidebar / NotificationBell | GET admin/inbox?limit=100 /15 | Any; mixed routes; no per-capability client filter for inbox navigation |
| Verifications | GET admin/verification/pending; GET admin/verification?status; GET admin/verification/counts; GET admin/verification/document?filePath; POST approve/reject/request-info/suspend/reactivate; PATCH note | Counts Any; list/doc/actions S; rejection/request/note body fields match controllers |
| Complaints / Flags | GET admin/complaints, admin/flags; POST complaint resolve/flag; POST admin/users/{id}/warn; POST verification/{providerId}/suspend or PATCH user deactivate | Complaints S; flags Any; mutations S; admin-target user controls additionally A |
| Users / Profile | GET admin/users?role&q&page&size; GET user/{id}/activity; GET admin/users/{id}; POST users/admins; PATCH permissions/deactivate/reactivate/user details; DELETE user; POST reset-password | Reads S/F; normal-user edit/reset/suspend S; admin-target edits/reset/status A; contact changes A; create/permissions/delete A; self/last-super protections server-side |
| Provider profile | GET providers/{id}; GET admin/providers/{id}/staff, /settings | Public provider detail supports admin visibility; admin staff/settings Any; main audit B-04 covers broad-read considerations |
| Bookings | GET admin/bookings?query&status/disputed&page&size; GET stats; GET export; POST force-cancel(reason), resolve-dispute(outcome,reason); GET booking/{id}/chat | List/export/chat S/F; stats Any; force-cancel/dispute F; body/query matching verified |
| Reviews | GET admin/reviews, admin/reviews/moderation; POST moderation/{caseId}/resolve?action; PATCH visibility?hidden | Reads Any; actions S; all reviews uses boolean hidden (AD-09); local CSV bypasses backend export sanitation |
| Photo moderation | GET admin/moderation; PATCH /{id}/action?status with notes body | Reads/actions S; reported images normalized to IMAGE and media URL under API base |
| Chat reports | GET admin/chat/moderation; POST /{caseId}/resolve?action | Reads Any; action S; senderName/message DTO handled |
| Safety | GET admin/safety?status&page&size=100; POST /{id}/resolve notes body | Read Any; close S; location/contact/delivery DTO handled; silent poll defect AD-05 |
| Settlements | GET overview/providers/detail/payout-report; POST confirm-payout?expectedAmount, remind; PATCH provider settlement-pause; GET ledger export | All reads/mutations F; confirm expected amount required and frozen payout snapshot verified; unused legacy api.settle supports required amount/reference |
| Rates / overrides | GET admin/settings/commission, /booking-rules; PATCH commission?percent, booking-rules fields; GET/PATCH provider settings/commission/travel-fee/booking-rules | Read Any; commission/travel F; booking rules A; clear semantics handled |
| Policies | GET terms?type; POST terms(version,type,contentEn,optional contentAr/changeNote) | Read Any; publish A; full text JSON body matches current TermsController |
| Support | GET support/contact; GET/PATCH support/admin/settings | Public contact; admin read Any; write A; labeled numbers/enabled/primary normalized |
| Audit | GET admin/audit?query&page&size; GET export?query | A; server paging/export query matches |

## Coverage inventory

- Application files reviewed: App.jsx (5,140 lines; all page/component handlers, effects, controls and state/render branches), api.js (1,328 lines; session/refresh, JSON/blob/download request paths, every consumer method/normalizer, mock router), main.jsx, styles.css (responsive layouts, focus, motion, tables, forms/modals), index.html.
- All routed screens: Dashboard; Safety OPEN/RESOLVED/ALL; Verifications four statuses and VerificationDetail/DocumentCard/DocumentLightbox; Complaints; Flags; Users customer/provider/admin filters/AddAdmin/Permissions; MyProfile/ProfileView/ActivityBlock; TOTP setup/enable/disable/clock; Bookings filters/exports/timeline/chat/dispute/cancel; Reviews Reported/Low rating/All/export; Photo moderation; Chat reports; Settlements/provider detail/commission/rules/travel overrides/payout/pause/reminder/export; Audit search/paging/export; Policies customer/provider terms/EN/AR/local drafts/preview/history; Booking rules; Support channels. Placeholder is dead/unrouted.
- Shared components: Icon, toast/runAction/Toaster, ConfirmHost, loading/skeleton/error/empty, Toolbar/SearchBar/ListFooter/Pagination/pageWindow, StatTiles/Tag/InlineBanner/Status/Priority/RolePill/Stars/Avatar/ProfileCell, Sidebar/MobileBar/TopBar/RefreshButton/NotificationBell, can/navAllowed, global refresh/useLoad. No error boundary, router/deep-link state, or page-level code splitting present. These absence observations alone are not bugs.
- Build/config/deploy docs: package.json/package-lock.json, vitest.config.js, Dockerfile, nginx.conf.template, README, .env.example, .gitignore, .dockerignore. Read HANDOFF history and verified current fixes instead of repeating obsolete claims. No source env/secrets opened.
- Test sources inspected (20 files plus setup): VerificationDetail.documents.test.jsx, TotpSetupCard.test.jsx, SettlementDetail.payout.test.jsx, Safety.test.jsx, Safety.refresh.test.jsx, ProfileView.pause.test.jsx, navPermissions.test.js, LoginScreen.test.jsx, Flags.confirm.test.jsx, components.small.test.jsx, App.signout.test.jsx, App.session.test.jsx, api.tokens.test.js, api.refresh-token.test.js, api.normalizers.test.js, api.non-json.test.js, api.idle-timeout.test.js, api.free-text-bodies.test.js, api.cross-tab-refresh.test.js, api.all-pages.test.js. Parent will report observed full-suite counts separately.
- Backend contract files inspected: AdminController, AdminUsersController, AdminBookingController, AdminInboxController, AdminProviderSettingsController, AdminSettingsController, VerificationController, ComplaintController, ModerationController, ReviewController, ChatController, SafetyController, SettlementController, SupportController, TermsController, AuthController cookie sections, Perms, AdminTwoFactorInterceptor, Pages, AdminUserRequest, ApiResponse DTO sections, ProviderController/ProviderServiceImpl admin retrieval. Parent/backend agent handles full authorization/business/infra audit.

## Current strengths / historical fixes verified

- F-05 implemented: access token module memory only; HttpOnly refresh cookie handled by server; localStorage holds a random non-secret session hint, old token keys removed at module load. Requests send credential inclusion and X-Requested-With only for auth paths. No historical localStorage credential-storage finding carried forward.
- Refresh deduplicates concurrent401 requests, uses Web Locks for tab coordination where available, guards stale refreshes with a session generation, avoids infinite retry for login/refresh, and distinguishes transient refresh errors from rejected credentials. Signout clears local credentials before a bounded3-second best-effort server call.
- Enrolled MFA setup requires password/current code and6-digit numeric input. Backend demands all admin2FA in prod; frontend gates upon the specific error code. Current copy still names only Finance/Super admin and offers Disable despite mandatory admin enrollment; cosmetic/workflow cleanup required.
- Mocks default off and demo credentials appear only in mock login. Proxy HTML errors keep useful HTTP status. Most writes surface server errors/toasts and confirmations; roles do not silently authorize privileged backend operations.
- S-05/F-03/F-04 server-side controls are present for finance/audit/booking/user/contact reads/actions; mismatch remaining is client UX (AD-08), not proof of bypass.
- Important queues walk server pages instead of old one-page500-row ceiling; user/bookings/audit lists use server search/paging; many effects have alive guards and search debounce; safety OPEN auto-refreshes15s and reacts to badge changes.
- Terms free text and admin notes use JSON body rather than URL; payout UI sends expectedAmount; documents fetched with bearer into blob previews, normal cleanup revokes object URLs. Private-doc Support restriction tested.
- nginx has restrictive CSP, frame-ancestors none, no-sniff, referrer/permissions/HSTS headers; assets immutable caching and app HTML no-store. React text renders default escaping; no dangerouslySetInnerHTML/eval-based app rendering found.
- CSS supports responsive UI, visible keyboard focus and several reduced-motion cases. Form labels, disabled busy actions, accessible search labels, skeletons and empty/error states are widespread.

## Dependencies / runtime

| Package | Manifest range | Locked version |
|---|---|---|
| react / react-dom | ^18.3.1 |18.3.1 |
| vite | ^6.0.5 |6.4.3 |
| @vitejs/plugin-react | ^4.3.4 |4.7.0 |
| lucide-react | ^0.468.0 |0.468.0 |
| vitest | ^4.1.11 |4.1.11 |
| jsdom | ^29.1.1 |29.1.1 |
| @testing-library/react | ^16.3.2 |16.3.3 |
| @testing-library/jest-dom | ^6.9.1 |6.9.1 |

LockfileVersion3 and manifest/lock ranges agree. Docker node20.20.2-alpine satisfies the tightest jsdom requirement (^20.19.0 / ^22.13.0 / >=24). nginxinc/nginx-unprivileged1.30.5-alpine serves build. Build runs npm ci --ignore-scripts, then tests+vite build. Default host node is12.22.12 and cannot run current toolchain; bundled node24.19.0 used only for read-only microchecks. No new npm advisory check/network lookup or browser/device smoke was run by this child; dependency vulnerability status belongs to parent live audit output rather than historical claims.

## Missing meaningful regression/integration coverage

Highest priority: CSV formula neutralization; policy type/load races and publish payload; payout remaining balance/status after success; rendered idle lock and all request variants; safety refresh outages/recovery and overlapping polls; global refresh behavior of every custom-loader screen; flag partial failure; real permission matrix incl administrative targets/contact changes; hidden ReviewDto normalization; settlement failed-load retry success; keyboard booking and modal focus behavior; actual configured escalation delivery. Existing auth regression tests are substantive but mostly mocked fetches, not a current real browser/back-end contract session across all permissions. Current source tests do not replace staging cookie/CORS/CSP/browser smoke, full admin CRUD/dispute/settlement flows, or financial provider sandbox verification.

