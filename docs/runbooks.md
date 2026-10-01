# Runbooks

One page per situation. Commands run from `deploy/` on the server unless noted.
`dc` below means `docker compose -f docker-compose.prod.yml`.

## SOS raised

What already happens automatically: the on-call phones in `SAFETY_ONCALL_PHONES`
get an SMS, the person's trusted contacts get an SMS, and the alert opens in the
admin panel's **Safety** screen. Alertmanager sends `SosRaised` to the team, and
`SosUnanswered` if an alert is still open after 10 minutes. Each text is tracked: the
Safety screen shows, per phone, "Delivered to gateway", "Sending…" or "Failed after 3
tries" with the error, and the person who raised it sees the same counts in the app.
A failed text to a trusted contact means **you** call that contact.

1. Open the admin panel → **Safety**. Open the alert: it shows both parties'
   phone numbers, the booking and a map link to the last location.
2. Call the person who raised it within 5 minutes. No answer: call again, then
   their trusted contact, then the other party.
3. If anyone may be in danger, call the police (122) or ambulance (123) with the
   address and map link. Do not wait for the person to confirm.
4. Close the alert only when the person is safe, with a note of what happened.
5. If the other party behaved badly: suspend them from **Users** (the booking
   history stays) and open a complaint so it's on record.

## Provider verification (SLA 24 h)

1. Admin panel → **Verifications** → oldest first.
2. Check the ID photos are readable, both sides, not expired, and that the selfie
   is the same person. Viewing a document is written to the audit log.
3. Check the business name, category and address make sense.
4. **Approve**, or **Reject with reason** (the provider sees the reason and can
   resubmit), or **Request info** for a missing or blurry document.

## Payment dispute

A customer said they didn't pay, or a provider said they weren't paid.

1. Admin panel → **Bookings** → filter **Disputes** → open the booking.
2. **Evidence** and **Chat** tabs: read both sides; **History** shows every step.
3. Message both parties on WhatsApp if the evidence isn't clear.
4. Resolve: paid in full, partly paid, not paid, or cancel the booking (with a
   reason). Both parties are told and the commission ledger follows the outcome.

## Account deletion request (outside the app)

The public page promises deletion **within 7 days**.

1. Confirm it's the owner: the request must come from the phone number or email
   on the account (reply to that number/email, don't trust the message alone).
2. Admin panel → **Users** → find them → **Delete**. This does the same as the
   in-app deletion: anonymises the account, erases addresses, trusted contacts,
   ID documents, selfie, gallery and avatar, and cancels upcoming bookings.
3. Reply that it's done.

## Restore the database from a backup

Backups: `deploy/backups/db/aiwa-*.dump` and `deploy/backups/uploads/uploads-*.tar.gz`,
one pair per night, kept `BACKUP_KEEP_DAYS` (14).

```bash
ls -1t backups/db | head          # newest first
./restore.sh backups/db/aiwa-20261001-020000.dump backups/uploads/uploads-20261001-020000.tar.gz
```

It asks you to type RESTORE, stops the backend, replaces the database (and the
uploads, if you pass the tarball), and starts the backend again. Anything written
after that backup is lost, so note the time and tell affected users.

Test a restore on a copy every month. A backup you've never restored is a guess.

A failed backup says `BACKUP FAILED: <reason>` in `dc logs backup`, leaves no
file behind and doesn't touch `backups/last-success`; the backup container turns
*unhealthy* when the last good backup is more than 26 hours old (`dc ps`). Set
`BACKUP_HEARTBEAT_URL` to a healthchecks.io / Better Stack heartbeat so a missed
night alerts someone even when nobody looks at the server.

## Backups off the server

A backup on the same disk doesn't survive losing the server. Copy `deploy/backups/`
somewhere else every night, for example with a cron job and `rclone` to an
S3-compatible bucket (Backblaze B2, Cloudflare R2, Hetzner Storage Box):

```cron
30 3 * * * rclone sync /srv/aiwa/deploy/backups remote:aiwa-backups --max-age 15d
```

The uploads tarballs contain ID documents: use a private bucket with encryption.

## Backend down / 5xx alerts

```bash
dc ps                      # is it running and healthy?
dc logs --tail 200 backend # the reason is usually in the last lines
dc restart backend
```

Out of memory (`HeapNearlyFull` first): give the server more RAM or lower traffic
spikes; the container restarts itself on OutOfMemoryError. Database unreachable:
`dc logs postgres`. Nothing obvious: roll back to the previous release
(`docs/release.md`, "Releasing and rolling back").

## Getting paged by alerts

Alertmanager sends every alert in `monitoring/alerts.yml` to the receivers in
`.env`: email (`ALERT_EMAIL_TO` + SMTP settings) and/or Telegram
(`ALERT_TELEGRAM_BOT_TOKEN`, `ALERT_TELEGRAM_CHAT_ID`). Critical alerts repeat every
30 minutes until resolved. If none is set the container refuses to start (`dc ps`
shows it restarting), and `AlertingPipelineDown` fires when it is down.
Send a test once after setup:
`dc exec alertmanager amtool alert add Test severity=critical --alertmanager.url=http://localhost:9093`.
Also set up an outside uptime check (UptimeRobot, Better Stack) on
`https://<API_DOMAIN>/api/actuator/health`: it still works when the whole server is down.
