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

What it does, in this order (audit I-02): it decrypts and checks every input and test-restores the dump into a
scratch database; **extracts the uploads tarball into a staging directory inside the uploads volume and verifies
it, before anything live is touched** (a full disk or a damaged archive stops here: nothing was changed); asks you
to type RESTORE; stops the backend; takes a **safety copy of the live database** (audit R4-06: verified by a scratch
restore, **encrypted with the backup key**, mode 600, stored in `backups/safety/pre-restore-<id>.dump.enc`; without a key
the restore refuses unless `BACKUP_ALLOW_UNENCRYPTED=1`, and it checks the free disk space first); restores the database in
one transaction; swaps the uploads with atomic renames that keep the previous files in `.restore-previous-<id>`; starts the
backend; and prints a reconciliation report.

If a step fails the pair is put back together, never left half-done:

| Failure | Result |
| --- | --- |
| extraction / disk space | nothing changed, backend never stopped |
| database restore | database rolled back (single transaction), staging removed, backend started |
| uploads swap | the swap undoes its own renames **and proves it** (every original name is back, no staged name is live), the database is restored from the safety copy, backend started |
| the uploads rollback itself fails (a rename error while undoing; audit R4-01) | exit 3 "RECOVERY FAILED": the backend stays **stopped**, the database is NOT touched again, the recovery journal `.restore-journal-<id>` and the previous and staged files are kept; fix the cause, then finish both halves in one step with `./restore.sh --undo <id>` (it resumes the uploads rollback from the journal and starts the backend only when the database and the uploads are both back); by hand: `uploads_swap.sh rollback <id>` until it succeeds, then `./restore.sh backups/safety/pre-restore-<id>.dump.enc` (database only: the uploads are the previous ones again by then) |
| the database cannot be put back either | backend stays **stopped** on purpose; the message names the safety dump and says the old uploads are intact |

The backend is started again only when the database and the uploads are known to be consistent. Whatever ends the script
while the backend is stopped, it says **STOPPED** on the way out.

Afterwards check the app, then free the retained copies:
`docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh purge <id>` and
`rm -f backups/safety/pre-restore-<id>.dump*`. Safety copies that are forgotten are removed by the backup job after
`BACKUP_SAFETY_KEEP_DAYS` (default = `BACKUP_KEEP_DAYS`), except while the matching `.restore-previous-<id>` still exists
(the pair is not purged; the job logs it). They are local only: the off-site job copies `db/` and `uploads/` and never
`safety/`. Budget the disk for them: one extra compressed database dump per restore, plus the plaintext copy in the
private temp dir (`TMPDIR`) while the restore runs.
#### Undoing a whole restore (audit R5-03)

There is one supported way to put back the database **and** the uploads that a restore replaced:

```bash
./restore.sh --undo <id>      # <id> is in backups/safety/pre-restore-<id>.dump[.enc] and in .restore-previous-<id>
```

Do **not** undo in two separate steps. `restore.sh <safety dump>` on its own restores only the database and starts the
backend, so for as long as the uploads are still the restored ones the application would run the old database against the
new files. `--undo` does it in this order: it checks that the safety copy and the previous uploads (`.restore-previous-<id>` or
the recovery journal) both exist, decrypts and test-restores the safety copy (the key is needed for an encrypted one), checks
the disk space, asks you to type UNDO, takes a new **safety copy of the current database** (`backups/safety/pre-restore-undo-<id2>.dump[.enc]`,
encrypted like the others, removed by the retention), **stops the backend**, restores the previous database in one
transaction, rolls the uploads back from the journal (verified; resumable), and **only then starts the backend** and
prints the reconciliation report.

| Failure | Result |
| --- | --- |
| previous uploads purged, unknown id, wrong or missing key, safety copy unreadable | refused before anything is stopped or changed |
| the database half | transaction rolled back, uploads untouched; the backend stays **stopped**; the message prints `./restore.sh --undo <id>` (repeat) and `docker compose -f docker-compose.prod.yml start backend` (give up and run the restored pair) |
| the uploads half (after the database was put back) | the backend stays **stopped** (old database on mismatched files must not run); journal, previous and staged files and both safety copies are kept; the message prints `docker compose -f docker-compose.prod.yml run --rm -T --entrypoint sh backup /uploads_swap.sh rollback <id>` (repeat until it succeeds) and then `docker compose -f docker-compose.prod.yml start backend` |

After a successful undo the files of the undone restore stay in the volume as `.restore-staging-<id>` (a recovery artifact);
remove them with `uploads_swap.sh purge <id>` when you are sure. `UNDO_DB_ONLY=1 ./restore.sh --undo <id>` undoes a
restore that was made without uploads. Anything written after the restored backup is lost: note the time and tell affected
users. The failure paths are tested without Docker by `deploy/backup/uploads_swap_test.sh` (injects a failure at every
rename, and at every rename of the way back; also a real `mv` wrapper that fails both ways) and
`deploy/restore_flow_test.sh` (the order of `restore.sh` with a fake docker, encrypted safety copy, disk-space refusal,
failed rollback keeps the backend stopped, and the paired undo: no backend start between the two halves, either half failing keeps it stopped, encrypted safety copies); both run in CI. They use stubs: the real-container drill (a real PostgreSQL and uploads volume) is still required before relying on `--undo`.

### Backup consistency (audit I-03)

The database dump and the uploads tarball are **two snapshots of a live system**, not one transaction. The order is the
guarantee: the dump is taken first, then the tarball, so every file the dump points at that still existed when tar ran is
in the tarball. The two differences that can occur: a file deleted between the snapshots (the restored database
points at a file that is not there: *missing*) and a file uploaded between them (in the tarball, not in the database:
*orphan*, harmless). `backup/manifest/snapshot-<stamp>.json` records when each half was taken, and after every restore
`restore.sh` prints `reconcile: N database references checked, M missing, K orphan files` and lists each missing path
(`backup/reconcile_uploads.sh`; the references come from `backup/uploads_references.sql`: avatars, gallery, ID
documents and selfies). The list ends with a terminator row; **a failed or cut-off reference query is reported as
"RECONCILIATION NOT PERFORMED" and never as "0 missing"**. The same check runs when each backup is made (audit R5-02): the references are
read **from the scratch restore of the dump being archived** (the database the dump was just verified into, not the live
database, which moves on after the dump) and compared with the file list of the tarball written afterwards, recorded in the manifest
(`reconcile`, `missing_references`) and as the metrics `aiwa_backup_reconcile_ok` / `aiwa_backup_missing_references`
(alert **BackupReconcileFailed**). A missing image shows as a broken picture until the owner uploads it again; it is never
fatal. **Remaining limits of the two-snapshot strategy:** the dump and the tarball are still taken at different moments, so
the check reports a difference, it does not prevent one; it detects a referenced file that is absent from the tarball, not a
file replaced under the same name, a damaged image, or a file uploaded and referenced only after the dump (an orphan); a scratch-query
failure or an incomplete list is a *failed* scan (`reconcile: failed`, metric 0, alert), never a clean one. The check has been
exercised with stub `psql`/`pg_dump` and a disposable volume only: rehearse it on a real PostgreSQL and uploads volume before
relying on the metric. If a stricter guarantee is ever needed: stop the backend for the minutes the backup takes, or snapshot the
volume at the filesystem level, then take both halves from the snapshot.

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

### Off-site retention policy (audit I-05)

`offsite.sh` copies and proves; it cannot enforce what the *bucket* keeps, and it never deletes remote files. The
privacy policy promises that off-site copies are gone within 30 days, so the bucket needs, and the launch sign-off
(gate 28) records:

- **Expiry**: a lifecycle rule that deletes objects (and non-current versions) after **30 days**. Not shorter than
  `BACKUP_KEEP_DAYS` (14), so a month-old problem can still be restored; not longer than the policy says.
- **Versioning or object lock** with a retention **no longer than the expiry**, and a write-only (or write + list) key on
  the server, so a compromised server can neither delete nor rewrite earlier backups.
- **Access**: a separate read key kept with the escrowed secrets, used only by the restore drill and a real restore.
- **Key escrow owner**: who holds `BACKUP_KEY_FILE` and `DOCUMENT_ENCRYPTION_KEY` outside the server (two people).
- Do not delete immutable backups by hand to "fix" the numbers; change the lifecycle rule and wait.

Evidence for the sign-off: a screenshot or CLI output of the lifecycle rule, the versioning/lock setting and the key's
permissions, and a successful restore drill from the bucket alone.
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

## Alert rules are tested

`deploy/monitoring/alerts_test.yml` unit-tests `alerts.yml` with promtool, using the label shape node-exporter really
emits (it strips the `--path.rootfs=/host` prefix, so the host root is `mountpoint="/"`; the old `/host` selector
never matched and `HostDiskLow` could not fire, audit I-01). CI runs it in the `monitoring-rules` job; locally:
`docker run --rm -v "$PWD:/w" -w /w --entrypoint promtool prom/prometheus:v2.54.1 test rules alerts_test.yml`
from `deploy/monitoring`. A passing unit test proves the rule, not the delivery: gate 26 still needs a real
low-disk alert received on staging.

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
