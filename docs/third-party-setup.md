# Third-party accounts (OPS-3)

Everything outside the code that production needs, in the order to set it up,
and exactly where each value goes. The backend refuses to start in the `prod`
profile if the SMS, email, push or on-call settings are missing
(`ProductionGuardConfig`: SMS URL **and key**, a real email provider with its key,
FCM credentials, on-call phones), and Alertmanager refuses to start without an alert
receiver, so these can't be forgotten silently.

| # | Account | Why | Values → where |
|---|---------|-----|----------------|
| 1 | **App IDs** (FE-28, done: `com.aiwa.app`) | Firebase and both stores are keyed on them; they can't change after publishing | `applicationId` in `android/app/build.gradle.kts`, bundle ID in Xcode |
| 2 | **Domain + DNS** | HTTPS, public legal pages, store links | A records for `<domain>`, `api.`, `admin.` → `deploy/.env` `SITE_DOMAIN`, `API_DOMAIN`, `ADMIN_DOMAIN` |
| 3 | **Egyptian SMS gateway** with a registered sender ID (e.g. Vodafone/Orange/Etisalat business SMS, Cequens, Victory Link) | sign-up codes, password reset, SOS texts | `SMS_PROVIDER=external`, `SMS_API_URL`, `SMS_API_KEY`, `SMS_SENDER` in `deploy/.env`. Sender ID approval takes days to weeks: start first |
| 4 | **Email sending** (e.g. Amazon SES, Mailgun, Postmark) with SPF/DKIM on the domain | email sign-up codes | `EMAIL_PROVIDER=http`, `EMAIL_API_URL`, `EMAIL_API_KEY`, `EMAIL_FROM` |
| 5 | **Firebase project** with the Android and iOS apps (needs #1) | push notifications (FE-3) | Backend: service-account JSON → `deploy/secrets/firebase-service-account.json`, `FCM_PROJECT_ID`. App: the five values in Project settings -> Your apps as `FIREBASE_*` variables for `tool/build_release.sh` (no config files needed); iOS also needs an APNs key uploaded to Firebase and the Push Notifications capability (entitlement already in the project) |
| 6 | **On-call phone numbers** | every SOS texts them | `SAFETY_ONCALL_PHONES` (comma-separated, +20…) |
| 7 | **Sentry** (free tier is enough to start): one backend and one Flutter project | crash and error reports | `SENTRY_DSN` in `deploy/.env`; app build: `SENTRY_DSN=… tool/build_release.sh` |
| 8 | **Uptime monitor** (UptimeRobot, Better Stack) | alert when the whole server is down; backup heartbeat | check `https://api.<domain>/api/actuator/health` every minute; a heartbeat URL → `BACKUP_HEARTBEAT_URL` |
| 8b | **Alert receiver**: an SMTP account (the email provider's SMTP works) and/or a Telegram bot + on-call group | Prometheus alerts reach a person | `ALERT_EMAIL_TO`, `ALERT_EMAIL_FROM`, `ALERT_SMTP_*` or `ALERT_TELEGRAM_*` in `deploy/.env` |
| 9 | **Off-site backup bucket** (Backblaze B2, Cloudflare R2, Hetzner Storage Box) | backups survive losing the server | rclone cron in `docs/runbooks.md` |
| 10 | **Google Play Console** ($25 once) and **Apple Developer** ($99/year) | publishing | listing answers in `docs/store-listing.md`; signing in `docs/release.md`; iOS team ID and link domain in `ios/Flutter/Signing.xcconfig` (from the `.example`), with the Push Notifications and Associated Domains capabilities on the App ID |
| 11 | **WhatsApp Business number** for support | the "Talk to AIWA" screen and account-deletion requests | admin panel → Policies & support |

Maps: the backend no longer uses a Google Maps key (map links open Google Maps
without one). Only add a key if the app later embeds a map, and restrict it to the
app's package name and SHA-1 / bundle ID.

Keep every key in the server's `deploy/.env` / `deploy/secrets/` (both git-ignored)
and in the team password manager. Never in git, chat or email.
