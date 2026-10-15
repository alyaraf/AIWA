# Release builds and deployment

## Mobile app (FE-1, FE-2)

A release build is blocked unless it has a real HTTPS API and a signing key:

- **Android**: `checkReleaseConfig` in `android/app/build.gradle.kts` runs before
  every release build and fails when `API_BASE_URL` is missing or not `https://`,
  or when `android/key.properties` is missing. The debug key is never used.
- **iOS / anything else**: `main.dart` refuses to start a release binary whose
  `API_BASE_URL` is not `https://`.

### One-time: create the upload key (Android)

```bash
keytool -genkey -v -keystore ~/aiwa-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `Android/aiwa_app/android/key.properties` (git-ignored, never commit it):

```properties
storeFile=/absolute/path/to/aiwa-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Keep the keystore and its passwords in the team's password manager, and turn on
Play App Signing when creating the Play Console app. In CI, write both files from
secrets before building.

iOS: set the team, distribution certificate and provisioning profile in Xcode
for the final bundle ID (FE-28).

### Build

```bash
cd Android/aiwa_app
API_BASE_URL=https://api.<domain>/api SENTRY_DSN=<dsn> tool/build_release.sh appbundle
API_BASE_URL=https://api.<domain>/api SENTRY_DSN=<dsn> tool/build_release.sh ipa
```

Optional: `APP_LINK_BASE=https://<domain>` makes shared profile links https App Links / Universal Links (FE-13); set `ANDROID_CERT_SHA256` and `APPLE_TEAM_ID` in `deploy/.env` so the site serves the verification files, and add `applinks:<domain>` to the Associated Domains capability in Xcode.

## Servers (BE-22, OPS-2, OPS-4, OPS-5, OPS-8)

`deploy/docker-compose.prod.yml` is the full stack (backend, admin panel, public site, backups) and runs everything behind Caddy, which gets and
renews TLS certificates automatically:

| Service  | Public? | Notes |
|----------|---------|-------|
| caddy    | 80/443  | `api.<domain>` → backend, `admin.<domain>` → admin panel, `<domain>` → public site |
| backend  | no      | Spring `prod` profile |
| admin    | no      | nginx with a strict CSP (`aiwa-admin-dashboard-updated/deploy/`) |
| postgres | no      | data volume; back it up (see OPS-2) |
| redis    | no      | password required |
| backup   | no      | nightly pg_dump + uploads tarball into `deploy/backups/`, kept 14 days; each one verified, `BACKUP FAILED` in the log otherwise, optional heartbeat ping |
| prometheus | no    | scrapes the backend with `METRICS_TOKEN`, alert rules in `deploy/monitoring/alerts.yml` |
| alertmanager | no  | sends the alerts by email and/or Telegram (`ALERT_*` in `.env`); won't start without a receiver |

The public site (`deploy/site/`) serves `/privacy`, `/terms` (live from the backend) and
`/delete-account`; use those URLs in the Play Console and App Store Connect. The privacy
policy is a **draft**: fill in the [bracketed] parts and have it reviewed before launch.

There is no other production compose file. `aiwa-backend/docker-compose.prod.yml` was removed (audit L-25) and the
backend-only guide `aiwa-backend/PRODUCTION_ENVIRONMENT_GUIDE.md` is background only. `aiwa-backend/docker-compose.yml` is
local-development PostgreSQL/Redis on 127.0.0.1, never a server file. A host with its own TLS proxy still runs this
stack (`deploy/docker-compose.prod.yml`), with the proxy in front of Caddy or Caddy's ports changed; the production
guards stay on (`ProductionGuardConfig`).



## Releasing and rolling back (RV-03)

**Release.** On the server checkout (`/srv/aiwa`); the `deploy-staging` CI job runs the same thing:

```bash
git fetch origin && git checkout --detach <sha> && bash deploy/deploy.sh
```

`deploy/deploy.sh` first takes a **pre-deploy backup** (`backup.sh once`: the same verified, encrypted dump and
uploads tarball as the nightly one, in `deploy/backups/`). If the backup fails, the deploy is refused and nothing
changes. It then appends `<utc time> <sha> <pre-deploy dump>` to `deploy/backups/releases.log`, and builds and
starts images tagged with the sha (`aiwa-backend:<sha>`, …). Earlier releases' images stay on the host; that is
what makes a rollback quick, so don't `docker image prune -a` while you may still need to go back. Afterwards check
`https://api.<domain>/api/actuator/health`.

**Rolling back.** First list the migrations the bad release brought in:

```bash
git diff --name-only <previous-sha> <bad-sha> -- aiwa-backend/src/main/resources/db/migration
```

| Its migrations | Roll back |
|---|---|
| none, or only additive: new tables, nullable columns or columns with a default, indexes | **Code only:** `bash deploy/deploy.sh --rollback`. The older image starts on the newer schema: Flyway skips migrations it doesn't know (`ignore-migration-patterns: "*:future"` in `application-prod.yml`) and Hibernate `validate` only checks the columns the old code maps. No data is lost. |
| drops or renames a column or table, changes a type, adds `NOT NULL` without a default, or rewrites data | **Code and database:** `bash deploy/deploy.sh --rollback`, then from `deploy/` restore the database only, using the dump on the bad release's line in `backups/releases.log`: `./restore.sh backups/db/aiwa-<stamp>.dump.enc`. Everything written since the deploy is lost. `restore.sh` takes its own safety copy first and stops/starts the backend ([runbooks](runbooks.md), "Restore the database from a backup"). Leave out the uploads tarball: a deploy doesn't change the uploads. |

`--rollback` goes to the release on the line before the last one, from the images on the host. It doesn't build,
doesn't back up and doesn't touch the database. A second `--rollback` in a row is refused (it would step back to the
bad release); to go further back give the target: `bash deploy/deploy.sh --rollback <sha>`. `ROLLBACK FAILED`
means that release's images are gone (pruned, or a new host). In that case rebuild it with `git checkout --detach <sha> && bash deploy/deploy.sh`,
which backs up first.

Write migrations so that the release before them can still run (add, backfill, and drop only in a later
release). Then a rollback is always the code-only kind. Not yet rehearsed on a real host: launch gate 54.
