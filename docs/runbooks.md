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
*unhealthy* when the last good backup is more than 26 hours old (`dc ps`). No
setting is needed for an alert: the backup container serves the time of the last
good backup to Prometheus, and **BackupStale** (older than 26 hours) or
**BackupMetricsMissing** (no status for an hour) reaches the team through
Alertmanager. `BACKUP_HEARTBEAT_URL` (healthchecks.io / Better Stack) is an optional
second signal that also works if the whole server is down.

### Encrypt the backups

Dumps and uploads (ID documents) are encrypted, and the key file is **required**
(`docker compose` refuses to start without `BACKUP_KEY_FILE`, and `backup.sh` refuses to
write an unencrypted copy). Create it once and keep a copy somewhere safe that is NOT
the server: without the key the backups cannot be restored.

```bash
cd deploy && (umask 077; openssl rand -base64 48 > secrets/backup.key)
echo 'BACKUP_KEY_FILE=./secrets/backup.key' >> .env
dc up -d backup
```

New files are then `aiwa-*.dump.enc` and `uploads-*.tar.gz.enc` (AES-256, openssl);
`./restore.sh` handles both forms and reads the key from `BACKUP_KEY_FILE` (default
`secrets/backup.key`). Older plain files stay until `BACKUP_KEEP_DAYS` removes them.
Without a key the backup fails with `BACKUP FAILED: no backup key ...` (so **BackupStale**
fires after 26 hours). Only a throwaway environment should set `BACKUP_ALLOW_UNENCRYPTED=1`
on the backup service; it then logs `WARNING ... NOT encrypted` and the
**BackupNotEncrypted** alert fires after an hour.

The backup container is built from `deploy/backup/Dockerfile` (the postgres alpine image with
`openssl` baked in), so nothing is installed from the network at run time (F-02). If a key is
mounted and openssl is missing for any reason, the backup does
NOT fall back to plain files: it logs `BACKUP FAILED: cannot encrypt ...`, keeps the old
last-success time, and **BackupStale** fires after 26 hours. A blank key file counts as
no key (**BackupNotEncrypted**). `./restore.sh` decrypts and checks the dump and the
uploads tarball into a temporary directory first (needs openssl on the server and room
for both files; the directory and the plaintext files in it are private to the user that
runs the script, and are removed when it ends). It is created under `/tmp`; for a large
backup, or when `/tmp` is not on the encrypted disk, point it at the restore volume with
`TMPDIR=/path/on/that/volume ./restore.sh ...`. A wrong key or a corrupt file stops it
before the app is stopped, the database is dropped or `/uploads` is emptied.

## Backups off the server

A backup on the same disk doesn't survive losing the server, so the stack ships the encrypted
backups off it itself (F-02): the `offsite` service in `docker-compose.prod.yml` runs
`backup/offsite.sh` every `OFFSITE_INTERVAL_SECONDS` (default 6 h). Compose refuses to start
without `OFFSITE_REMOTE`.

Set up once:

1. Create a **private** bucket at an S3-compatible provider (Backblaze B2, Cloudflare R2, Hetzner
   Storage Box) and turn on **versioning or object lock** with a retention of at least the
   backup retention. This is what makes the remote copy survive a compromised server.
2. Create a write-only (or write + list) access key for that bucket. Do not give the server a key that can delete.
3. `deploy/secrets/rclone.conf` (git-ignored) with a remote, then set in `.env`
   `OFFSITE_REMOTE=<remote>:<bucket>/aiwa`:

   ```ini
   [aiwa]
   type = s3
   provider = Cloudflare
   access_key_id = ...
   secret_access_key = ...
   endpoint = https://<account>.r2.cloudflarestorage.com
   ```
4. `dc up -d --build`, then `dc logs offsite` must say `offsite ok`.

How it behaves: `rclone copy --immutable` (never `sync`: a wiped or encrypted local `backups/` is not
mirrored over the remote, and an existing remote file is never rewritten), only `*.enc` files are sent,
and `rclone check` proves the copy before `aiwa_offsite_last_success_timestamp_seconds` moves.
Alerts: **OffsiteBackupStale** (copy older than 26 h) and **OffsiteBackupMetricsMissing**.
Set `OFFSITE_HEARTBEAT_URL` for an external "no ping" alert too.

### Keys: store them off the server

The encrypted backups are useless without the keys, and ID documents are unreadable without
`DOCUMENT_ENCRYPTION_KEY`. Keep copies of **`BACKUP_KEY_FILE`, `DOCUMENT_ENCRYPTION_KEY`,
`TOTP_ENCRYPTION_KEY` and `JWT_SECRET`** in a password manager or secret store that is not on this
server and that at least two people can open. Losing the first two means the data cannot be recovered.

### Restore drill (a launch gate)

On a clean machine, with only the off-server bucket and the escrowed keys:

```bash
rclone copy aiwa:aiwa-backups/db ./restore-test/db        # latest .enc dump
rclone copy aiwa:aiwa-backups/uploads ./restore-test/uploads
BACKUP_KEY_FILE=./restore.key ./restore.sh restore-test/db/aiwa-<stamp>.dump.enc restore-test/uploads/uploads-<stamp>.tar.gz.enc
```

Then sign in as an admin and open one ID document. Record the date, the operator and the backup
used in `docs/launch-signoff.md`. Repeat after any change to the backup scripts and at least quarterly.

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

Turn on the monitor's **SSL certificate expiry** warning (14 days) for the API, admin and site domains too: Caddy renews
automatically, but a failed renewal (DNS change, port 80 blocked) is only visible from outside until the certificate lapses.
The stack itself watches Redis (`RedisDown`), disk, memory, the database pool and the backup copies.

## Load smoke test before launch

`deploy/loadtest/smoke.js` is a k6 script for the public read paths (health, nearby, search). Run it against staging only:

```bash
k6 run -e BASE_URL=https://staging.example.com deploy/loadtest/smoke.js
```

It ramps to 50 users for two minutes and exits non-zero if more than 1% of requests fail or p95 passes 800 ms. While it runs, watch `hikaricp_connections_active` in Prometheus: if it sits at the pool size (`DB_POOL_SIZE`, default 20), raise the pool before launch (keep it under PostgreSQL `max_connections`).

## First admin: remove the bootstrap password

`ADMIN_EMAIL` / `ADMIN_PASSWORD` in `deploy/.env` create the first super admin on the first start
only. After you have logged in as that admin (and set up 2FA), delete the `ADMIN_PASSWORD` line from
`.env` and recreate the backend (`dc up -d backend`). The account stays in the database; a password
left in the environment is a standing credential.
