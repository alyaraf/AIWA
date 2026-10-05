# Admin session hardening (S-04, F-05)

## Current state (implemented 2026-10-05, F-05)

No admin credential is readable from JavaScript after the page is gone.

| What | Where it lives |
| --- | --- |
| Access token (15 min) | Memory of the admin page only (`src/api.js`). Gone on reload. |
| Refresh token (8 h, single use) | `aiwa_admin_refresh` cookie: `HttpOnly; Secure; SameSite=Strict; Path=/api/auth`. Set by the backend, never in a JSON body for admin accounts. |
| "A session exists" hint | `localStorage` key `aiwa_admin_session`: a random id, no secret. Lets a reload decide whether to try restoring, and lets other tabs notice a sign-in or sign-out. |
| Idle timestamp | `localStorage` key `aiwa_admin_last_activity` (30 min limit, `VITE_ADMIN_IDLE_MINUTES`). |

How it works:

- `/auth/login` (no 2FA), `/auth/2fa/verify`, `/auth/2fa/enable`, `/auth/refresh`, `/auth/me/phone` and `/auth/me/email/verify`
  return the refresh token as the cookie for ADMIN accounts (`AuthController.tokenResponse`). Other users (the mobile
  apps) still get it in the body.
- `POST /auth/refresh` with no body token uses the cookie and **requires `X-Requested-With: aiwa-admin`** (403 otherwise):
  CSRF defence on top of `SameSite=Strict`. A refresh token sent in the body still works for API clients.
- `POST /auth/logout` revokes the cookie's token and clears the cookie.
- Reload: no access token in memory and the hint is present, so the first request gets 401, refreshes through the
  cookie and retries. With no cookie the login screen shows.
- Tabs share the cookie, so refreshes take turns with the Web Locks API (`navigator.locks`); a refresh token is single
  use and two tabs refreshing together would otherwise trip reuse detection. A sign-in in another tab changes the
  hint; this tab drops its access token and gets one for the new session. A sign-out elsewhere signs this tab out.
- Tokens an older build left in `localStorage` (`aiwa_admin_access_token`, `aiwa_admin_refresh_token`) are removed on load.
- `JwtAuthFilter` still accepts only the `Authorization` header, so the access token never becomes a cookie.

Tests: backend `AdminRefreshCookieApiTest` (cookie flags, no body token, CSRF header, rotation and single use, logout,
customers unchanged); admin `api.tokens`, `api.refresh-token`, `api.cross-tab-refresh`, `api.idle-timeout`,
`App.session`, `App.signout`. Checked by hand in a browser against a local backend: after sign-in `localStorage` holds only
the hint, `document.cookie` is empty, a reload restores the session through the cookie, a refresh without the header
is 403, and after logout a refresh is 401.

## Deployment requirements

- Serve the admin panel and the API from the **same registrable domain** (`admin.example.com` and `api.example.com`),
  otherwise `SameSite=Strict` stops the browser sending the cookie. The compose file already does this.
- `CORS_ALLOWED_ORIGINS` must be the exact admin origin (compose sets `https://${ADMIN_DOMAIN}`; credentials are allowed).
- The cookie is `Secure` when `AUTH_COOKIE_SECURE` is true (always in the prod profile). The cookie path follows
  `server.servlet.context-path` (`/api`), so it is sent to `/api/auth/*` only.
- Admins signed in before the upgrade are signed out once (their old token is not a cookie); they sign in again.

## What is still true

An XSS in the admin origin can still call the API with the in-memory access token while the page is open (15 minutes at
most), but it can no longer steal a token that outlives the page. Keep the CSP, the dependency audit gate, mandatory 2FA
for every admin and the idle sign-out.

## Round 3 additions (2026-10-05: AD-04, P-03, P-04)

- **One session-end signal.** `api.js` exports `onSessionEnded`; the App subscribes and drops every view (sets the
  session to null) when the idle limit passes or the server rejects a session and its refresh. Before, only the request that
  noticed learned about it, and a screen that swallowed the error kept the previous admin's rows on screen.
- **Idle limit everywhere.** Every request, document image and CSV export goes through the same checks (`request`,
  `authedBlobFetch`): idle limit, one refresh-and-retry on 401, generation check. A timer (15 s), tab focus and
  `visibilitychange` also call `enforceIdleLimit()`, so an abandoned workstation clears without any request.
- **Late answers are dropped (P-04).** A response that arrives after the session changed (sign-out, expiry, another tab
  signing in as someone else) is discarded with `code: "SESSION_CHANGED"` / `stale: true` and status 0 (never 401, so it
  cannot end the new session). Nothing from the previous session is shown or cached.
- **Sign-out and sign-in take turns (P-03).** The logout response clears the refresh cookie; a slow logout that finished
  after the next sign-in had set its cookie would clear the new one. `login` now waits for a sign-out still in flight.
  Server side nothing changed: the cookie is still cleared by `POST /auth/logout`.
- A leftover idle record from an old session does not block a new sign-in; it is cleared.

Tests: `api.session-integrity.test.js` (stale success after sign-out and after sign-in, logout/login ordering, idle blob
helpers, rejected refresh, truncation, review DTO), `api.idle-timeout`, `api.cross-tab-refresh`. Checked in a real browser
(Vite dev server in mock mode): Escape and focus on dialogs, keyboard Bookings rows, the stale SOS banner on `offline`.
**Not** checked: a real two-tab cookie scenario against the deployed API (launch gate 29).
