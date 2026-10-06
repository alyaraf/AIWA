# API business and ownership flows — round 4

Baseline: 290a05f0606545c073c22e1753cc9ad5c584fa5a. Project: D:/AIWA PROJECT/AIWA. Date: 2026-10-05. Read with [api-inventory.md](api-inventory.md), which contains all 183 handler mappings, exact access annotations, signatures, body constraints, responses and statically reachable operations/error keys.

Controllers resolve under D:/AIWA PROJECT/AIWA/aiwa-backend/src/main/java/com/aiwa/controller. Adjacent service/entity/repository packages implement the business boundaries. Paths below are relative to the /api context. SUPPORT/FINANCE/SUPER_ADMIN are capabilities on ADMIN principals; super-admin has the effective support/finance powers.

## Shared rules

Public discovery/files/terms/contact routes permit guests; a supplied JWT is still validated. Protected requests apply token purpose/expiry, current account state, durable revocation/rotation and effective session cutoff. Admin non-auth routes also enforce MFA when enabled. Controller/URL gates compose with owner/participant checks; an identifier does not confer access.

DTO @Valid constraints run for annotated bodies; query/map/free-text/multipart paths rely on explicit bounds and state checks. Framework errors and GlobalExceptionHandler cover 400/401/403/404/409/413/415/429/503 and unexpected 500; exact reachable keys and response signatures are in the inventory. Persistence constraints complement validation.

The operation lists are static reachability, including branches/overloads, not runtime query traces. ORM lazy loads, callbacks, jobs and framework-auth operations require separate measurements. H2 suite success does not prove PostgreSQL lock/isolation semantics.

## Controller families

| Controller | Inputs, ownership and state flow | Persistence/integration and consumer |
| --- | --- | --- |
| AccountController | Own address/contact/default operations; bounded inputs; account deletion requires identity/password and history checks | Owned user/address/contact records; archive/history-preserving delete. Mobile. Booking snapshot now insulated; SOS mapper remains R4-02 |
| AuthController | Register/login/OTP/reset/logout/refresh/me/password/contact/MFA/device; ADMIN registration refused; purpose-bound OTP/challenges; cookie refresh header | BCrypt, users, OTP/attempt state, token rotation/revocation, device cleanup, encrypted TOTP, gateway sends. Mobile/admin; providerOnboarding derived server-side |
| ProviderController | Guest/public eligible discovery/profile/service/search; bounds for paging/geo/query. Provider create/update/dashboard resolve own profile | Profile/services/rating/booking reads, transactional profile changes, public home masking and state-filtered contacts. Mobile; selected admin detail consumers |
| ProviderModeController | Own online/vacation/mode/fee/radius plus travel-buffer 0–60; allowed resumption/balance rules | Own provider/service updates. Mobile schedule now uses narrow travel-buffer route |
| ServiceController | Public active service selection; provider CRUD validates provider ownership, category/duration/money and linked records | Service/provider/staff/bookings; deactivate preserves referenced history. Mobile |
| StaffController | Public active selection; provider CRUD/assignments compare provider ownership and service/staff association | Staff/service association/history. Retry deduplicates client desired names; no general server batch idempotency guarantee |
| AvailabilityController | Owned provider/staff schedules; weekday/time/range consistency | Availability/staff schedule records consumed by slots and creation; real concurrent booking/management checks still needed |
| BookingController | Public slots; customer create validates owned address, service/staff/date/time/availability/radius/idempotency. Participant list/detail/contact and transition-specific actions | Locks/versions/unique constraints, snapshots, notifications, safety and ledger. New amendment is customer/home/own-address/state/cutoff gated; accepted → pending |
| ChatController | Booking participant/contact-state gates, bounded message/report; admin report read/resolve SUPPORT | Chat, booking and moderation records, notifications/audit. Mobile and admin reported chat |
| ReviewController | Eligible own booking/direction, bounded rating/comment/tags and no duplicate; public hidden filtering; admin moderation SUPPORT | Review/directional uniqueness/rating aggregates/moderation cases. Mobile/admin |
| SavedController | Own provider saves/list/delete, eligibility and unique pair | Transactional idempotent delete now tested; mobile saved list |
| NotificationController | Own list/count/read operations | User-bound notifications; paged mobile continuation now advances only on success |
| GalleryController | Public approved gallery; own provider multipart add/remove/order/cover and eligible report; file size/type/count/ownership checks | Gallery/file/moderation records, normalized public images. Private documents are handled by VerificationController, avatars by AuthController |
| TermsController | Public latest typed policy; accept validates caller role/type/current version; ADMIN policy read and SUPER publish/deactivate | Terms policies/acceptance uniqueness, per-type version. Mobile full text/version-pinned acceptance; admin editor |
| SupportController | Public contact projection; ADMIN settings read; SUPER mutation with bounded email/phone/text/enabled/primary fields | Support settings and audited administrative changes; public contact is not a substitute for SOS delivery |
| ComplaintController | Authenticated own complaint creation/list with booking/provider participation and bounded text | Complaint/support workflow and notifications. Mobile |
| SafetyController | Booking participant SOS/close/report; optional bounded geo fields; admin queue/resolve SUPPORT | Durable safety event/delivery/retry. SOS textual destination mapper is R4-02; reported GPS stays distinct |
| SettlementController | Own provider balance/payment report plus capability-gated admin confirmation/adjustment/export; amount/reference and frozen-membership checks | Locked ledger/payout report state, BigDecimal money, notifications/audit; provider report does not itself settle the ledger |
| AdminController | Capability-sensitive dashboard/read/actions; reviews/flags SUPPORT and finance/bookings according to annotations/ownership helpers | Admin aggregates, bookings, reviews with copied tags, moderation and selected mutations. Dashboard consumers |
| AnalyticsController | Administrative analytics/export access as exact annotations specify | Aggregate booking/provider metrics and export projections; report days bounded |
| AdminUsersController | Read/edit/delete/suspend/reset with named capability and target privilege checks; protected contact exposure | User state/session cutoff, anonymization/history, audits and masked password-delivery result |
| VerificationController | Own provider submit/resubmit; SUPPORT queue/private documents/approve/reject/request-info; path/ownership checks | Encrypted verification files and provider state, audits and provider notifications |
| AdminProviderSettingsController | Capability-gated provider setting overrides and historical staff read | Provider overrides/history, validation and audit; staff history read SUPPORT |
| AdminBookingController | FINANCE force-cancel/dispute resolution with reason/outcome; SUPPORT/FINANCE chat read/export | Booking transactions/state/ledger adjustments, chat and audits; administrative intervention |
| AdminSettingsController | ADMIN settings reads; FINANCE commission changes; SUPER booking rules, bounded numeric/enum inputs | Platform settings and audit; provider override hierarchy |
| AdminInboxController | ADMIN envelope; each source filtered by effective SUPPORT/FINANCE | Support gets SOS/complaint/verification/moderation; support/finance dispute/closure; finance payment reports; bounded feed |
| ModerationController | SUPPORT content/photo moderation and action checks | Moderation cases and public-image/provider relations, notes/audit |
| AuditController | SUPER-sensitive trail/export per exact annotations; bounded search/page; CSV neutralization | Audit/history records and controlled exports; no secrets promised to a generic admin |
| DevTotpResetController | Development-only MFA reset helper scoped to the local profile | User TOTP reset; mixed prod/local guard rejects production activation. Framework actuator health is separate from these mapped controllers |

**Naming note:** The inventory is authoritative for the exact classes and routes. This family table describes their responsibilities; it does not widen a route's annotation or imply a consumer call exists.

## Authentication lifecycle

1. App/dashboard submits contact/password or a purpose-bound OTP/challenge. Registration rejects ADMIN, validates fields and consumes verification state.
2. Auth service resolves active identity, attempt limits and BCrypt, completes MFA where required, persists/rotates refresh state and returns access credentials.
3. Mobile uses secure storage; admin stores access only in memory and receives a secure HttpOnly refresh cookie. The admin session hint is nonsecret.
4. Requests verify purpose/expiry/revocation/current account cutoff; expired temporary-password sessions are rejected using effectiveTokensValidAfter.
5. A 401 may trigger one serialized refresh/retry; a multipart body is cloned. Logout captures/revokes relevant old credentials and clears device association/storage.
6. Profile DTO populates identity/permissions/onboarding. Remaining mobile operation races are R4-05; already-loaded admin data and blob completion are R4-03/04.

## Booking, amendment and finance

Customer selection → service/staff/slot/address/idempotency payload → validation → owned user/address/provider/service/staff → provider lock/overlap/state checks → frozen money/commission/destination → pending booking and notifications → DTO → client list.

Editing an address now leaves booking destination unchanged. Explicit amendment selects another owned active address and checks home visit, pending/accepted state, cutoff and radius. It replaces only the agreed destination snapshot and moves an accepted visit back to pending for provider confirmation. The mobile flow is not yet implemented.

Provider acceptance/travel/check-in/start/completion and customer cancellation/proposal/contest/cash response verify participant/state and timing. Commission obligations use snapshots and unique membership; finance confirmations/adjustments validate amounts and locked state. No card gateway transfer is present. Cash reports and payout confirmation are distinct.

## Safety and moderation

Participant SOS → persisted incident + optional reported GPS + contacts/on-call delivery entries → gateway retries/outcome states → support queue → resolution note/audit. The admin SOS textual address still resolves the mutable saved relation (R4-02), and client queue ordering still permits an older empty response to erase a newer incident (R4-07).

Provider verification reads authorized decrypted documents. Reviews/chat/photos/complaints have distinct eligibility/report/resolve paths and SUPPORT gates. Client warning/suspension followed by case closure now keeps partial-success retry state, avoiding duplicate first actions.

## File persistence and recovery

Public upload validation → header bounds → normalized image storage → reference update. Private upload → checked input → encrypted storage → authorized document endpoint. Database commit/filesystem operation are distinct durability boundaries.

Backup → database dump then uploads tar → check/encrypt → manifest → offsite copy. Restore → decrypt/check scratch database → preflight/stage uploads → stop backend → safety dump → transactional DB restore → file swap → start → reference report. R4-01 shows the unsafe rollback assumption; R4-06 shows the safety dump outside encryption/retention; I-03 remains a two-snapshot consistency limitation.
