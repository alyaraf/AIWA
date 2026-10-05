# Admin session hardening (S-04)

## Current state

The admin dashboard keeps its access and refresh tokens in `localStorage`
(`aiwa_admin_access_token`, `aiwa_admin_refresh_token`). The CSP in
`aiwa-admin-dashboard-updated/deploy/nginx.conf.template` and the absence of HTML-injection sinks
make theft unlikely, but any future XSS, malicious extension or compromised browser profile can read
them.

## Done in this pass (incremental)

- **Idle sign-out.** After 30 minutes without a click or keypress (`VITE_ADMIN_IDLE_MINUTES`, build
  time; `0` turns it off) the next API call, or the next poll of an open panel, drops both tokens and
  the admin signs in again (with 2FA). A profile left open or recovered later no longer holds a usable
  session. Tests: `src/test/api.idle-timeout.test.js`.
- Admin refresh tokens already live 8 hours (`JWT_ADMIN_REFRESH_EXPIRATION_MS`), access tokens 15
  minutes, and Super admin / Finance 2FA is enforced server side.

## Remaining migration (not done: needs backend and client changes together)

Goal: no admin credential readable from JavaScript.

1. **Backend.** For `ADMIN` users, `/auth/login`, `/auth/2fa/verify` and `/auth/refresh` set the refresh
   token as `HttpOnly; Secure; SameSite=Strict; Path=/api/auth` and omit it from the JSON body;
   `/auth/refresh` and `/auth/logout` read it from the cookie. Require a custom header
   (`X-Requested-With`) on those calls as CSRF defence in depth. `JwtAuthFilter` keeps accepting only the
   `Authorization` header (AU-14 removed cookie auth deliberately), so the access token never becomes a
   cookie.
2. **Rotation races.** Refresh tokens are single-use with reuse detection. With a shared cookie jar two
   tabs refreshing at once would trip it. Serialise refreshes across tabs in the client (Web Locks API,
   `navigator.locks`) or add a short grace window for the previous token on the server.
3. **Client.** Keep the access token in memory only; on page load call `/auth/refresh` to obtain it.
   Replace the `storage` listeners in `api.js` / `App.jsx` with `BroadcastChannel` messages for
   sign-out and user change. Update the tests in `src/test/api.*.test.js` and `App.*.test.jsx`.
4. **Deployment.** Admin and API share the registrable domain (`admin.` / `api.`), so `SameSite=Strict`
   works; CORS needs `allow-credentials` with the exact admin origin (already not `*`).
5. **Then** remove the `aiwa_admin_*` localStorage keys and the idle-timeout shim.
