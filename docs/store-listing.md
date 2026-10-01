# Store listings and legal (OPS-4)

Answers for the Play Console and App Store Connect, taken from what the code
actually does (permissions in `AndroidManifest.xml` / `Info.plist`, fields the
backend stores, `AccountDeletionService`). Re-check this page whenever a feature
starts collecting something new.

## URLs (served by `deploy/site/`, see `docs/release.md`)

| What | URL |
|------|-----|
| Privacy policy | `https://<domain>/privacy` |
| Terms | `https://<domain>/terms` |
| Account deletion (Play requires it) | `https://<domain>/delete-account` |
| Support | the WhatsApp number set in the admin panel (Policies & support) |

The privacy policy is a draft. Before submitting: fill in the [bracketed] parts
(company, SMS/email/hosting providers, minimum age, privacy email), have a lawyer
check it against Egypt's Personal Data Protection Law (No. 151 of 2020), and
remove the draft box (both the English and the Arabic section; the Arabic one is a translation of the same draft).

## Permissions the app asks for

| Permission | Used for | When asked |
|------------|----------|-----------|
| Location, while in use (fine + coarse) | providers near you, home-visit address, SOS position | onboarding priming screen, then when needed |
| Camera / photos | profile photo, provider gallery, provider ID card and selfie | when you tap to add a photo |
| Notifications (Android 13+) | booking and safety updates | onboarding priming screen |

No background location, contacts, microphone, SMS or call-log access.

## Google Play: Data safety form

Data is encrypted in transit (HTTPS): **Yes**. Users can request deletion: **Yes**
(in-app and the web page). Data shared with third parties for their own use: **No**
(SMS/email/push/crash providers are service providers, which Play does not count as sharing).

| Data type (Play category) | Collected | Optional? | Purpose |
|---------------------------|-----------|-----------|---------|
| Personal info → Name | Yes | Required | Account management, App functionality |
| Personal info → Email address | Yes | Optional | Account management |
| Personal info → Phone number | Yes | Required | Account management, App functionality, Fraud prevention/security |
| Personal info → Gender | Yes | Required | App functionality (palette, provider matching) |
| Personal info → Address | Yes | Optional | App functionality (home visits) |
| Personal info → Other info (national ID images, providers only) | Yes | Required for providers | Fraud prevention, security and compliance |
| Location → Precise location | Yes | Optional | App functionality (search, home visits, SOS) |
| Photos and videos → Photos | Yes | Optional (required for provider ID) | App functionality, Fraud prevention |
| Messages → Other in-app messages | Yes | Optional | App functionality (booking chat) |
| App activity → Other user-generated content (reviews, complaints) | Yes | Optional | App functionality |
| Financial info → Purchase history (cash booking amounts, commission) | Yes | Required | App functionality, Account management |
| App info and performance → Crash logs, Diagnostics | Yes | Required | Analytics (crash reporting via Sentry, no name/phone/email) |
| Device or other IDs (push token) | Yes | Required | App functionality (notifications) |
| Contacts | **No** (trusted contacts are typed in, not read from the phone) | | |

Not collected: payment card info, health, audio, files, web browsing, calendar,
installed apps, advertising ID.

## App Store: App Privacy labels

"Data Linked to You" (none of it is used for tracking; answer **No** to tracking):

- Contact Info: Name, Email Address, Phone Number, Physical Address
- Location: Precise Location
- User Content: Photos, Customer Support (complaints), Other User Content (reviews, chat)
- Identifiers: User ID
- Purchases: Purchase History
- Sensitive Info: Other (government ID images, providers only)
- Diagnostics: Crash Data (linked by user ID only)

Purposes for all: App Functionality; for ID images and phone also "Other purposes →
fraud prevention". No third-party advertising, no data brokers.

## Content rating (IARC questionnaire)

- Category: Utility/Productivity (service booking), not a game.
- Violence, sexual content, profanity, drugs, gambling: none.
- Users can interact / communicate: **Yes** (booking chat between a customer and a
  provider, only inside a booking; reports and admin moderation exist).
- Shares user location with other users: **Yes** (the home-visit address goes to the
  booked provider; the SOS position goes to support and trusted contacts).
- Digital purchases: **No** (payment is cash on visit).
- Expected result: Everyone / 3+ with "Users Interact, Shares Location"; set the
  audience in Play to 18+ to match the policy.

## Screenshots to prepare

Phone screenshots in both palettes (charcoal and mauve), English and Arabic:
Home, Discover with results, Provider profile, Booking (date and slot), Tracking
with the safety card, Chat, and for the provider app Today and Bookings. The golden
tests (`Android/aiwa_app/test/goldens/`) render these screens and are a good guide;
take the store images from a real device (OPS-7) so fonts and status bars are right.

## Account deletion: what the public page promises (verified in code)

`AccountDeletionService` (used by in-app deletion and by support's **Delete** in the
admin panel) erases name, phone, email, avatar, push token, saved addresses and
their coordinates, trusted contacts, and for providers the ID photos, selfie and
gallery; cancels upcoming bookings. Bookings, reviews, chats, ledger, SOS records
and the audit log are kept without the name. Backups roll over after 14 days.
Requests from outside the app: support confirms identity and deletes within 7 days
(`docs/runbooks.md`).
