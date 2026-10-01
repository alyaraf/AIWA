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

- Access token 15 min (`JWT_EXPIRATION_MS`), refresh 7 days, MFA challenge 5 min;
  each has a `typ` claim and only access tokens authenticate requests.
- Issue time in ms (`iatms`); `users.tokens_valid_after` cuts off every older
  token (password reset, phone change, suspension).
- Refresh rotates: the used token is spent with a database INSERT
  (`revoked_tokens`), so reuse fails even with Redis down. Logout records the
  access and refresh token there too (header or cookie). Redis is only a fast
  check in front of the table.
- [ ] Confirm the lifetimes. [ ] Confirm the cookie flags (`aiwa.auth.cookie-secure=true` in prod).

## 3. Second factor (DR-017)

- TOTP for admins; setup and disable need the password and, when on, a current code.
- The MFA challenge is single-use, checked against the session cut-off.
- [ ] Decide whether 2FA is **required** for every admin account (recommended for
  SUPER_ADMIN and FINANCE) and enforce it at login.

## 4. Admin accounts (DR-007, DR-031)

- Roles: SUPPORT, FINANCE, SUPER_ADMIN (`security/Perms`). Changing another admin
  (edit, permissions, reset, deactivate, reactivate) needs SUPER_ADMIN.
- The last active super admin can't be removed; changes take row locks first.
- `@Version` on users: a stale save can't undo a suspension.
- The first super admin comes from `ADMIN_EMAIL` / `ADMIN_PASSWORD` once
  (`AdminBootstrapConfig`); change that password after first sign-in.
- [ ] Agree who holds SUPER_ADMIN at launch (at least two people).
- [ ] Remove `ADMIN_PASSWORD` from `.env` after the first start.

## 5. Abuse limits (BE-8, DR-028)

- Per IP: sign-in, register, OTP, reset, refresh, 2FA (`RedisRateLimitFilter`, 429).
- Per phone/email: 3 OTPs per 10 min, 10 per day; 5 guesses per code; codes spent atomically.
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
| | | |
