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

## Servers (BE-22, OPS-8)

`deploy/docker-compose.prod.yml` runs everything behind Caddy, which gets and
renews TLS certificates automatically:

| Service  | Public? | Notes |
|----------|---------|-------|
| caddy    | 80/443  | `api.<domain>` → backend, `admin.<domain>` → admin panel |
| backend  | no      | Spring `prod` profile |
| admin    | no      | nginx with a strict CSP (`aiwa-admin-dashboard-updated/deploy/`) |
| postgres | no      | data volume; back it up (see OPS-2) |
| redis    | no      | password required |

```bash
cd deploy
cp .env.example .env   # fill in every value; never commit .env
docker compose -f docker-compose.prod.yml up -d --build
```

Point the DNS A records for `api.<domain>` and `admin.<domain>` at the server
before the first start so Caddy can get certificates.

A managed PostgreSQL with point-in-time recovery is still recommended over the
bundled container (OPS-2); set `SPRING_DATASOURCE_URL` to it and drop the
`postgres` service.
