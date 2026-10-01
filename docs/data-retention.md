# Data kept after an account is deleted (R2-18)

`AccountDeletionService` erases the account itself: name, email, phone, photo,
password, 2FA secret, push devices, saved addresses (scrubbed), trusted contacts,
ID documents, selfie and gallery images, and upcoming bookings are cancelled.
The items below are **not** erased today. Each needs an owner decision, recorded in
the privacy policy (`deploy/site/privacy.html`) once legal has reviewed it
(Law 151/2020: keep personal data only as long as the purpose needs it).

| Data | Where | Why it is kept | Proposed rule (owner to confirm) |
|------|-------|----------------|----------------------------------|
| Chat messages of past bookings | `chat_messages` | Evidence for disputes and safety reports involving the other party | Keep 12 months after the booking, then delete the text. Keep longer only if a complaint or SOS is open on that booking |
| SOS events with location | `safety_events`, `sos_deliveries` | Safety incidents may involve the police | Keep 24 months; keep coordinates only for SOS events (not other safety events) |
| Notification text | `notifications` | Inbox history; holds names and service names | Delete with the account (no further use) |
| Bookings, reviews, commission ledger | `bookings`, `reviews`, `commission_ledger_entries` | Accounting and the other party's history; already shown as "Deleted user" | Keep, linked to the anonymised account, as long as tax rules require (usually 5 years) |
| Audit log | `audit_log` | Who did what in the admin panel | Keep 24 months |
| Backups | `deploy/backups`, off-site copy | Disaster recovery | 14 days on the server, 30 days off-site; a deleted account disappears from backups when they age out. Say so in the privacy policy |
| Redis keys (OTP counters, rate limits, token blacklist) | Redis | Short-lived security state | Already expire on their own (minutes to 7 days) |
| Files whose database row is gone | `uploads/` | Leftovers from before the R2-13 fix | One-off clean-up script after launch; new uploads no longer leave orphans |

Once confirmed, the time-based rules become a nightly job (same pattern as the
settlement sweep). Until then nothing is deleted automatically beyond what is
listed under "erases" above.
