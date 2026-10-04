# Security walkthrough: sign-in, sessions and admin accounts (E-1)

The 2026-10-01 review escalated these areas for a walkthrough with the code
owner. Every itemised finding is fixed and tested (V-01, DR-002, DR-007,
DR-016, DR-017, DR-018, DR-030, DR-031). This page is the agenda: go through
each section with the code open, tick it, and record decisions at the bottom.
E-1 closes when every box is ticked.

## 1. Who is signing in (V-01, R2-19)

- `UserRepository.findByLogin`: a value with "@" is an email (case-insensitive),
  anything else a phone normalized to `+20…` (`util/Identifiers`). No lookup
  tries one as the other.
- Emails must be real addresses on register and profile update.
- Refresh and MFA tokens carry `userId`; `AuthServiceImpl.userOf` resolves by id.
- [ ] Agree no other code path looks a user up by a client-supplied string.

## 2. Tokens and sessions (DR-002, DR-018, DR-030)

- Access token 15 min (`JWT_EXPIRATION_MS`), refresh 7 days (8 hours for admin accounts,
  `JWT_ADMIN_REFRESH_EXPIRATION_MS`), MFA challenge 5 min;
  each has a `typ` claim and only access tokens authenticate requests.
- Issue time in ms (`iatms`); `users.tokens_valid_after` cuts off every older
  token (password reset, phone change, suspension).
- Refresh rotates: the used token is spent with a database INSERT
  (`revoked_tokens`), so reuse fails even with Redis down. Logout records the
  access and refresh token there too. A revocation written while Redis was down is
  rechecked in the table until that token would have expired anyway (AU-14). Redis
  is only a fast check in front of the table.
- Only the `Authorization: Bearer` header authenticates a request; the old
  `accessToken` cookie is no longer accepted (AU-14). The cookie is still set on
  login and cleared on logout but nothing reads it.
- [ ] Confirm the lifetimes.

## 3. Second factor (DR-017)

- TOTP for admins; setup and disable need the password and, when on, a current code.
- The MFA challenge is single-use, checked against the session cut-off.
- **Decided 2026-10-04 and enforced:** in prod a SUPER_ADMIN or FINANCE admin without
  2FA gets 403 `auth.error.admin_2fa_required` on every `/admin/**` call and the panel
  shows the setup card (`AdminTwoFactorInterceptor`, `REQUIRE_ADMIN_2FA`, default on in
  prod). SUPPORT admins are not forced.
- TOTP secrets are encrypted at rest once `TOTP_ENCRYPTION_KEY` is set (AU-08).
- [ ] Confirm SUPPORT stays optional, or require it for every admin too.
- [ ] Set `TOTP_ENCRYPTION_KEY` and `DOCUMENT_ENCRYPTION_KEY` in `deploy/.env` and keep a copy of both with
  the other secrets: without them, admins with 2FA can’t sign in and stored ID photos can’t be opened.

## 4. Admin accounts (DR-007, DR-031)

- Roles: SUPPORT, FINANCE, SUPER_ADMIN (`security/Perms`). Changing another admin
  (edit, permissions, reset, deactivate, reactivate) needs SUPER_ADMIN.
- The last active super admin can't be removed; changes take row locks first.
- `@Version` on users: a stale save can't undo a suspension.
- Support’s password reset sends the temporary password to the user by SMS or email; the admin
  never sees it (AU-08). Contact changes by support notify the user and the old phone/email.
- ID documents and selfies are encrypted at rest once `DOCUMENT_ENCRYPTION_KEY` is set.
- The first super admin comes from `ADMIN_EMAIL` / `ADMIN_PASSWORD` once
  (`AdminBootstrapConfig`); change that password after first sign-in.
- [ ] Agree who holds SUPER_ADMIN at launch (at least two people).
- [ ] Remove `ADMIN_PASSWORD` from `.env` after the first start.

## 5. Abuse limits (BE-8, DR-028)

- Per IP: sign-in, register, OTP, reset, refresh, 2FA (`RedisRateLimitFilter`, 429).
- Per phone/email: 3 OTPs per 10 min, 10 per day; 5 guesses per code; codes spent atomically.
- Across everyone: OTP texts only to +20 numbers, at most 1,000 an hour and 10,000 a day
  (`OTP_ALLOWED_COUNTRY_CODES`, `OTP_MAX_GLOBAL_SENDS_HOUR/DAY`), with an alert (H-4).
- Per account: chat 30/min, reports 10/h, complaints 5/h, uploads 30/h; SOS texts
  to contacts at most 5 SOS a day (support always alerted).
- [ ] Confirm the numbers fit the expected traffic.

## 6. Things the code can't decide

- [ ] Who reviews the audit log (`/admin/audit`) and how often.
- [ ] What happens when an admin leaves: deactivate the same day (sessions end at once).
- [ ] Incident contact for a suspected account takeover (add to `docs/runbooks.md`).

## Decisions

| Date | Decision | By |
|------|----------|----|
| 2026-10-04 | 2FA is required for SUPER_ADMIN and FINANCE admins and enforced at the API (not just the panel). | Owner |
| | | |
