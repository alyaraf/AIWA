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


