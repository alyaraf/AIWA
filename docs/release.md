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

Optional: `APP_LINK_BASE=https://<domain>/p` for share links (FE-13).

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
| backup   | no      | nightly pg_dump + uploads tarball into `deploy/backups/`, kept 14 days |
| prometheus | no    | only with `--profile monitoring`; scrapes the backend with `METRICS_TOKEN`, alert rules in `deploy/monitoring/alerts.yml` |

The public site (`deploy/site/`) serves `/privacy`, `/terms` (live from the backend) and
`/delete-account`; use those URLs in the Play Console and App Store Connect. The privacy
policy is a **draft**: fill in the [bracketed] parts and have it reviewed before launch.

`aiwa-backend/docker-compose.prod.yml` is the older backend-only file for hosts that
already have their own TLS proxy; its guides stay valid.

```bash
cd deploy
cp .env.example .env   # fill in every value; never commit .env
mkdir -p secrets        # put firebase-service-account.json here (git-ignored)
openssl rand -hex 32 | tee secrets/metrics-token   # and put the same value in .env as METRICS_TOKEN
docker compose -f docker-compose.prod.yml --profile monitoring up -d --build
```

Backups, restores and alerts: see `docs/runbooks.md`. Copy `deploy/backups/` off the
server every night; the restore script was tested end to end (database and uploads).

Point the DNS A records for `<domain>`, `api.<domain>` and `admin.<domain>` at the server
before the first start so Caddy can get certificates.

A managed PostgreSQL with point-in-time recovery is still recommended over the
bundled container (OPS-2); set `SPRING_DATASOURCE_URL` to it and drop the
`postgres` service.

## Staging (OPS-2, OPS-6)

Run the same stack on a second, smaller server with its own `deploy/.env`
(`staging.<domain>`, `api.staging.<domain>`, `admin.staging.<domain>`, test SMS
credentials, its own database). Never point staging at production data.

The CI job `deploy-staging` deploys every green push to `main` there. Turn it on in
GitHub → Settings → Secrets and variables → Actions:

| Kind | Name | Value |
|------|------|-------|
| Variable | `STAGING_HOST` | the server's hostname or IP |
| Variable | `STAGING_USER` | the SSH user that owns `/srv/aiwa` and can run docker |
| Variable | `STAGING_API_DOMAIN` | e.g. `api.staging.<domain>` (health check) |
| Secret | `STAGING_SSH_KEY` | a private key used only for this deploy |
| Secret | `STAGING_KNOWN_HOSTS` | output of `ssh-keyscan <host>` |

On the server, once: `git clone <repo> /srv/aiwa`, then create `/srv/aiwa/deploy/.env` and
`deploy/secrets/` as above. Production deploys stay manual until staging has run
for a while.
