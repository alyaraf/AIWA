# Current backend controller API inventory

Generated from the current Java source in D:/AIWA PROJECT/AIWA on 2026-10-06. Routes below are relative to the `/api` servlet context. Mapping line numbers are verified from source. This is a static inventory, not proof of successful runtime behavior.

All requests traverse the security/filter chain; public routes do not require a JWT unless their controller/service says so. Protected requests apply JWT/session, URL and method checks and (for an admin principal outside exempt auth routes) the admin two-factor interceptor. `Perms.SUPPORT`, `FINANCE`, and `SUPER_ADMIN` permit the named authority and super-admin as defined by `Perms`. Transitive operations below are statically reachable repository/integration calls, including conditional branches and overloads, not a claim that all run for one request. ORM lazy loads, callbacks, jobs and framework authentication also perform operations outside this static list; see api-flows.md and audit.md.

Common errors: absent/invalid session 401; missing role/permission 403 `auth.error.forbidden_role`; object ownership 403 or deliberate 404; missing object 404 `error.not_found`; invalid JSON/parameters/Bean Validation/business rules 400; unique/FK/optimistic conflict 409; throttle 429; unavailable dependency 503; multipart too large 413; unsupported media type 415; wrong verb 405; unexpected exceptions 500. Endpoint-specific controller and reachable service error keys are listed below; api-flows.md explains business/ownership checks. `@Valid` body field constraints are reproduced in the appendix.

## AccountController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AccountController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/account/addresses` — addresses (line 48)

- Purpose: addresses.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.SavedAddressDto>>> addresses( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `SavedAddressRepository.findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/account/addresses` — addAddress (line 57)

- Purpose: addAddress.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SavedAddressDto>> addAddress( @Valid @RequestBody SavedAddressRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `addressRepo.clearDefaultExcept, addressRepo.findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc, addressRepo.save`.
- Reachable database/integration operations: `SavedAddressRepository.clearDefaultExcept, SavedAddressRepository.findByUserIdAndArchivedFalseOrderByDefaultAddressDescCreatedAtDesc, SavedAddressRepository.save, UserRepository.findByLogin`.
- Reachable business error keys: `account.error.addresses_limit`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `account.error.addresses_limit`.

### PUT `/account/addresses/{id}` — updateAddress (line 84)

- Purpose: Edit one of your saved addresses (defaultAddress=true makes it the only default).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SavedAddressDto>> updateAddress( @PathVariable Long id, @Valid @RequestBody SavedAddressRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `addressRepo.clearDefaultExcept, addressRepo.save`.
- Reachable database/integration operations: `SavedAddressRepository.clearDefaultExcept, SavedAddressRepository.findById, SavedAddressRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/account/addresses/{id}` — deleteAddress (line 111)

- Purpose: deleteAddress.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> deleteAddress( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `addressRepo.delete, addressRepo.save, bookingRepo.existsBySavedAddressId`.
- Reachable database/integration operations: `BookingRepository.existsBySavedAddressId, SavedAddressRepository.delete, SavedAddressRepository.findById, SavedAddressRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/account/trusted-contacts` — trustedContacts (line 143)

- Purpose: People who get an SMS when you trigger an SOS.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.TrustedContactDto>>> trustedContacts( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `TrustedContactRepository.findByUserIdOrderByCreatedAtAsc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/account/trusted-contacts` — addTrustedContact (line 152)

- Purpose: Add a trusted contact (up to 5).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.TrustedContactDto>> addTrustedContact( @Valid @RequestBody TrustedContactRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `trustedContactRepo.countByUserId, trustedContactRepo.save`.
- Reachable database/integration operations: `TrustedContactRepository.countByUserId, TrustedContactRepository.save, UserRepository.findByLogin`.
- Reachable business error keys: `account.error.trusted_contact_self, account.error.trusted_contacts_limit`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `account.error.trusted_contact_self; account.error.trusted_contacts_limit`.

### DELETE `/account/trusted-contacts/{id}` — removeTrustedContact (line 178)

- Purpose: removeTrustedContact.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> removeTrustedContact( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `trustedContactRepo.delete, trustedContactRepo.findById`.
- Reachable database/integration operations: `TrustedContactRepository.delete, TrustedContactRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/account` — deleteAccount (line 196)

- Purpose: Close your account — needs {currentPassword} in the body.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> deleteAccount( @RequestBody(required = false) com.aiwa.dto.request.AuthRequest.CurrentPassword request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `accountDeletion.requireSelfDeletable`.
- Operations: `accountDeletion.delete, accountDeletion.requireSelfDeletable, authService.confirmPassword`.
- Reachable database/integration operations: `BookingRepository.findByCustomerIdAndStatus, BookingRepository.findByProviderIdAndStatusIn, BookingRepository.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc, BookingRepository.save, CommissionLedgerRepository.findByProviderIdAndStatusIn, GalleryImageRepository.deleteAll, GalleryImageRepository.findByProviderIdOrderByIdAsc, NotificationRepository.save, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, PushDeviceRepository.deleteByUserId, PushDeviceRepository.findByUserId, SavedAddressRepository.findByUserId, SavedAddressRepository.save, TrustedContactRepository.deleteAll, TrustedContactRepository.findByUserIdOrderByCreatedAtAsc, UserRepository.claimLoginAttempt, UserRepository.clearLoginAttempts, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `account.error.delete_commission_owed, account.error.delete_live_bookings, auth.error.too_many_attempts, auth.error.wrong_password`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminBookingController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminBookingController.java`. Class authorization: `"hasRole('ADMIN')"`.

### POST `/admin/bookings/{id}/force-cancel` — forceCancel (line 29)

- Purpose: Force-cancel any active booking (ADMIN · Finance).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> forceCancel( @PathVariable Long id, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `auditService.record, bookingService.adminForceCancel`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/bookings/{id}/resolve-dispute` — resolveDispute (line 41)

- Purpose: Resolve a disputed payment — outcome: PAID | UNPAID | NO_SHOW | CANCEL (ADMIN · Finance).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> resolveDispute( @PathVariable Long id, @RequestParam(required = false) String outcome, @RequestParam(required = false) Boolean paid, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `auditService.record, bookingService.adminResolveDispute`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.not_disputed`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/bookings/{id}/chat` — chat (line 57)

- Purpose: Read the chat thread for a booking (ADMIN · Support or Finance, read-only, audited).
- URL access: Authenticated URL filter. Method/class authorization: `"hasAuthority('PERM_SUPPORT') or hasAuthority('PERM_FINANCE')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.ChatMessageDto>>> chat(@PathVariable Long id)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, chatRepo.findByBookingIdOrderByCreatedAtAsc`.
- Reachable database/integration operations: `AuditLogRepository.save, ChatMessageRepository.findByBookingIdOrderByCreatedAtAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/dashboard` — dashboard (line 45)

- Purpose: Platform dashboard stats (ADMIN) - FR-019.
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AdminDashboardDto>> dashboard()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingRepo.count, bookingRepo.countByCreatedAtBetween, bookingRepo.countByPaymentStatus, bookingRepo.countByStatus, bookingRepo.sumRevenueByStatus, bookingRepo.sumRevenueByStatusBetween, complaintRepo.countByStatus, complaintRepo.countHighPriorityByStatus, ledgerRepo.countDistinctProvidersByStatus, providerRepo.countByVerificationStatus, providerRepo.countByVerificationStatusAndVerifiedAtAfter, safetyRepo.countByTypeAndResolvedFalse, userRepo.countByRole, userRepo.countByRoleAndCreatedAtBetween`.
- Reachable database/integration operations: `BookingRepository.count, BookingRepository.countByCreatedAtBetween, BookingRepository.countByPaymentStatus, BookingRepository.countByStatus, BookingRepository.sumRevenueByStatus, BookingRepository.sumRevenueByStatusBetween, CommissionLedgerRepository.countDistinctProvidersByStatus, ComplaintRepository.countByStatus, ComplaintRepository.countHighPriorityByStatus, ProviderProfileRepository.countByVerificationStatus, ProviderProfileRepository.countByVerificationStatusAndVerifiedAtAfter, SafetyEventRepository.countByTypeAndResolvedFalse, UserRepository.countByRole, UserRepository.countByRoleAndCreatedAtBetween`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/bookings` — bookings (line 100)

- Purpose: List all bookings for admin monitoring (SUPPORT or FINANCE).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> bookings( @RequestParam(required = false) BookingStatus status, @RequestParam(defaultValue = "false") boolean disputed, @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `bookingRepo.adminSearch`.
- Reachable database/integration operations: `BookingRepository.adminSearch`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/bookings/export` — exportBookings (line 117)

- Purpose: Export the filtered bookings list as CSV (SUPPORT or FINANCE).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<String> exportBookings( @RequestParam(required = false) BookingStatus status, @RequestParam(defaultValue = "false") boolean disputed, @RequestParam(required = false) String query)`.
- Validation helpers: `PageRequest.of`.
- Operations: `bookingRepo.adminSearch`.
- Reachable database/integration operations: `BookingRepository.adminSearch`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/bookings/stats` — bookingStats (line 143)

- Purpose: Bookings monitor stat tiles (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> bookingStats()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingRepo.countByCreatedAtBetween, bookingRepo.countByPaymentStatus, bookingRepo.countByStatusIn, bookingRepo.countByStatusInAndCreatedAtBetween`.
- Reachable database/integration operations: `BookingRepository.countByCreatedAtBetween, BookingRepository.countByPaymentStatus, BookingRepository.countByStatusIn, BookingRepository.countByStatusInAndCreatedAtBetween`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/reviews` — reviews (line 166)

- Purpose: List all reviews for admin moderation.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> reviews( @RequestParam(required = false) String query, @RequestParam(defaultValue = "5") int maxRating, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `reviewRepo.searchAdmin`.
- Reachable database/integration operations: `ReviewRepository.searchAdmin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/flags` — flags (line 182)

- Purpose: List flagged complaints for admin review.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> flags( @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `complaintRepo.searchFlagged`.
- Reachable database/integration operations: `ComplaintRepository.searchFlagged`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminInboxController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminInboxController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/inbox` — inbox (line 50)

- Purpose: Recent admin-attention items across the whole app, newest first (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.InboxItemDto>>> inbox( @RequestParam(defaultValue = "20") int limit, org.springframework.security.core.Authentication auth)`.
- Validation helpers: `PageRequest.of`.
- Operations: `bookingRepo.findByClosureFlaggedAtIsNotNullAndStatusInOrderByClosureFlaggedAtDesc, bookingRepo.findByPaymentStatusOrderByCreatedAtDesc, complaintRepo.findByStatusOrderByCreatedAtDesc, moderationRepo.findByStatusOrderByCreatedAtDesc, providerRepo.findBySettlementReportedAtIsNotNullOrderBySettlementReportedAtAsc, providerRepo.findByVerificationStatus, safetyRepo.findByTypeAndResolvedOrderByCreatedAtDesc`.
- Reachable database/integration operations: `BookingRepository.findByClosureFlaggedAtIsNotNullAndStatusInOrderByClosureFlaggedAtDesc, BookingRepository.findByPaymentStatusOrderByCreatedAtDesc, ComplaintRepository.findByStatusOrderByCreatedAtDesc, ModerationCaseRepository.findByStatusOrderByCreatedAtDesc, ProviderProfileRepository.findBySettlementReportedAtIsNotNullOrderBySettlementReportedAtAsc, ProviderProfileRepository.findByVerificationStatus, SafetyEventRepository.findByTypeAndResolvedOrderByCreatedAtDesc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminProviderSettingsController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminProviderSettingsController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/admin/providers/{providerId}/settings` — getSettings (line 41)

- Purpose: Get this provider's commission + booking-rule overrides and the effective values (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> getSettings( @PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/providers/{providerId}/staff` — staff (line 56)

- Purpose: List this provider's staff, including inactive/departed ones (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.StaffMemberDto>>> staff( @PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `staffRepo.findByProviderIdOrderByFullNameAsc`.
- Reachable database/integration operations: `ProviderProfileRepository.findById, StaffMemberRepository.findByProviderIdOrderByFullNameAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/providers/{providerId}/commission` — updateCommission (line 69)

- Purpose: Set or clear this provider's custom commission rate — applies to future bookings (ADMIN · Finance).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateCommission( @PathVariable Long providerId, @RequestParam(required = false) BigDecimal percent, @RequestParam(required = false, defaultValue = "false") boolean clear)`.
- Validation helpers: `platformSettings.validateCommissionPercent`.
- Operations: `auditService.record, platformSettings.validateCommissionPercent, providerRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById, ProviderProfileRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/providers/{providerId}/travel-fee` — updateTravelFee (line 94)

- Purpose: Set or clear this provider's home-service travel fee — applies to future bookings (ADMIN · Finance).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateTravelFee( @PathVariable Long providerId, @RequestParam(required = false) BigDecimal amount, @RequestParam(required = false, defaultValue = "false") boolean clear)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, providerRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById, ProviderProfileRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `provider.travel_fee.must_be_non_negative; provider.travel_fee.too_large`.

### PATCH `/admin/providers/{providerId}/booking-rules` — updateBookingRules (line 122)

- Purpose: Set or clear this provider's booking-rule overrides — applies to future bookings (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderSettingsDto>> updateBookingRules( @PathVariable Long providerId, @RequestParam(required = false) Integer cancellationCutoffHours, @RequestParam(required = false) BigDecimal providerCancelPenaltyPercent, @RequestParam(required = false) Long responseWindowMinutes, @RequestParam(required = false, defaultValue = "") String clear)`.
- Validation helpers: `platformSettings.validateBookingRules`.
- Operations: `auditService.record, platformSettings.validateBookingRules, providerRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById, ProviderProfileRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminSettingsController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminSettingsController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/settings/commission` — getCommission (line 24)

- Purpose: Get the current platform commission rate (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionSettingDto>> getCommission()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `platformSettings.getCommissionPercent`.
- Reachable database/integration operations: `PlatformSettingsRepository.findFirstByOrderByIdAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/settings/commission` — updateCommission (line 33)

- Purpose: Update the platform commission rate — applies to future bookings (ADMIN · Finance).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionSettingDto>> updateCommission( @RequestParam BigDecimal percent)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, platformSettings.updateCommissionPercent`.
- Reachable database/integration operations: `AuditLogRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PlatformSettingsRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/settings/booking-rules` — getBookingRules (line 44)

- Purpose: Get booking rules — cancellation cutoff, provider penalty, response window (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingRulesDto>> getBookingRules()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `PlatformSettingsRepository.findFirstByOrderByIdAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/settings/booking-rules` — updateBookingRules (line 50)

- Purpose: Update booking rules — applies to future bookings (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingRulesDto>> updateBookingRules( @RequestParam(required = false) Integer cancellationCutoffHours, @RequestParam(required = false) BigDecimal providerCancelPenaltyPercent, @RequestParam(required = false) Long responseWindowMinutes)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, platformSettings.getCancellationCutoffHours, platformSettings.getProviderCancelPenaltyPercent, platformSettings.getResponseWindowMinutes, platformSettings.updateBookingRules`.
- Reachable database/integration operations: `AuditLogRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PlatformSettingsRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AdminUsersController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AdminUsersController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/users` — listUsers (line 50)

- Purpose: List all users — filter by role, search by name/phone/email.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.UserDto>>> listUsers( @RequestParam(required = false) String role, @RequestParam(required = false) String q, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `userRepo.adminSearch`.
- Reachable database/integration operations: `BookingRepository.countByCustomerId, BookingRepository.countByProviderId, UserRepository.adminSearch`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Invalid role filter: `.

### POST `/admin/users/admins` — createAdmin (line 76)

- Purpose: Create another admin user (SUPER_ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> createAdmin( @Valid @RequestBody AdminUserRequest.CreateAdmin request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, notificationService.send, userRepo.existsByEmailIgnoreCase, userRepo.existsByPhone, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.countByCustomerId, BookingRepository.countByProviderId, NotificationRepository.save, PushDeviceRepository.findByUserId, UserRepository.countActiveSuperAdmins, UserRepository.existsByEmailIgnoreCase, UserRepository.existsByPhone, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.invalid_email`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `Email already in use; Email or phone is required; Phone number already in use`.

### GET `/admin/users/{id}` — getUser (line 125)

- Purpose: Get user detail by ID.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> getUser(@PathVariable Long id)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `userRepo.findById`.
- Reachable database/integration operations: `BookingRepository.countByCustomerId, BookingRepository.countByProviderId, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/users/{id}/activity` — activity (line 135)

- Purpose: Recent bookings, reviews and complaints for one account (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserActivityDto>> activity(@PathVariable Long id)`.
- Validation helpers: `PageRequest.of`.
- Operations: `bookingRepo.findByCustomerIdOrderByCreatedAtDesc, bookingRepo.findByProviderIdOrderByCreatedAtDesc, userRepo.findById`.
- Reachable database/integration operations: `BookingRepository.findByCustomerIdOrderByCreatedAtDesc, BookingRepository.findByProviderIdOrderByCreatedAtDesc, ComplaintRepository.findByReporterIdOrderByCreatedAtDesc, ReviewRepository.findByUserIdOrderByCreatedAtDesc, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/users/{id}/deactivate` — deactivate (line 199)

- Purpose: Deactivate (suspend) a user account (ADMIN · Support; another admin needs SUPER_ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> deactivate( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, bookingService.cancelForSuspendedProvider, providerRepo.findByUserId, userRepo.countActiveSuperAdmins, userRepo.countByRoleAndActive, userRepo.findById, userRepo.lockActiveSuperAdmins, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findByProviderIdAndStatusIn, BookingRepository.save, NotificationRepository.save, ProviderProfileRepository.findByUserId, PushDeviceRepository.findByUserId, UserRepository.countActiveSuperAdmins, UserRepository.countByRoleAndActive, UserRepository.findById, UserRepository.findByLogin, UserRepository.lockActiveSuperAdmins, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Can't deactivate ; Cannot deactivate the last active admin user; You cannot deactivate your own admin account`.

### PATCH `/admin/users/{id}/reactivate` — reactivate (line 252)

- Purpose: Reactivate a deactivated user account (ADMIN · Support; another admin needs SUPER_ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> reactivate( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, userRepo.findById, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, UserRepository.countActiveSuperAdmins, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/admin/users/{id}` — deleteUser (line 270)

- Purpose: Delete a user account (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> deleteUser( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `accountDeletion.requireNoLiveVisit`.
- Operations: `accountDeletion.delete, accountDeletion.requireNoLiveVisit, auditService.record, userRepo.countActiveSuperAdmins, userRepo.countByRole, userRepo.delete, userRepo.findById, userRepo.lockActiveSuperAdmins`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findByCustomerIdAndStatus, BookingRepository.findByProviderIdAndStatusIn, BookingRepository.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc, BookingRepository.save, GalleryImageRepository.deleteAll, GalleryImageRepository.findByProviderIdOrderByIdAsc, NotificationRepository.save, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, PushDeviceRepository.deleteByUserId, PushDeviceRepository.findByUserId, SavedAddressRepository.findByUserId, SavedAddressRepository.save, TrustedContactRepository.deleteAll, TrustedContactRepository.findByUserIdOrderByCreatedAtAsc, UserRepository.countActiveSuperAdmins, UserRepository.countByRole, UserRepository.delete, UserRepository.findById, UserRepository.findByLogin, UserRepository.lockActiveSuperAdmins, UserRepository.save`.
- Reachable business error keys: `admin.error.delete_live_visit`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Can't delete ; Cannot delete the last admin user; User has related records. Deactivate the account instead.; You cannot delete your own admin account`.

### PATCH `/admin/users/{id}/permissions` — updatePermissions (line 313)

- Purpose: Update an admin's permissions (SUPER_ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> updatePermissions( @PathVariable Long id, @RequestParam java.util.List<String> permissions, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, userRepo.countActiveSuperAdmins, userRepo.findById, userRepo.lockActiveSuperAdmins, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.countByCustomerId, BookingRepository.countByProviderId, BookingRepository.findByProviderIdAndStatusIn, BookingRepository.save, NotificationRepository.save, ProviderProfileRepository.findByUserId, PushDeviceRepository.findByUserId, UserRepository.countActiveSuperAdmins, UserRepository.countByRoleAndActive, UserRepository.findById, UserRepository.findByLogin, UserRepository.lockActiveSuperAdmins, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Can't remove super admin from ; Permissions apply to admin users only`.

### PATCH `/admin/users/{id}` — editUser (line 341)

- Purpose: Edit a user's contact details — name / email / phone (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> editUser( @PathVariable Long id, @jakarta.validation.Valid @RequestBody AdminUserRequest.EditUser request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, userRepo.existsByEmail, userRepo.existsByEmailIgnoreCase, userRepo.existsByPhone, userRepo.findById, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.countByCustomerId, BookingRepository.countByProviderId, NotificationRepository.save, PushDeviceRepository.findByUserId, UserRepository.countActiveSuperAdmins, UserRepository.existsByEmail, UserRepository.existsByEmailIgnoreCase, UserRepository.existsByPhone, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.invalid_email`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `A user must keep at least an email or a phone number; That email is already in use; That phone number is already in use`.

### POST `/admin/users/{id}/reset-password` — resetPassword (line 446)

- Purpose: Set a one-time temporary password for a locked-out user and send it to THEM by SMS or email (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, String>>> resetPassword( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `requireSuperAdmin`.
- Operations: `auditService.record, notificationService.send, userRepo.clearLoginAttempts, userRepo.findById, userRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, PushDeviceRepository.findByUserId, UserRepository.clearLoginAttempts, UserRepository.countActiveSuperAdmins, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AnalyticsController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AnalyticsController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/analytics/bookings` — bookings (line 25)

- Purpose: Daily booking counts (completed / cancelled / total) for the last N days (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.BookingAnalyticsPointDto>>> bookings( @RequestParam(defaultValue = "14") int days)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `BookingRepository.countByDateAndStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/analytics/export` — export (line 32)

- Purpose: Export the daily booking series as CSV (SUPPORT or FINANCE).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT_OR_FINANCE`.
- Input and return signature: `public ResponseEntity<String> export(@RequestParam(defaultValue = "30") int days)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `BookingRepository.countByDateAndStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AuditController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AuditController.java`. Class authorization: `com.aiwa.security.Perms.AUDIT_READ`.

### GET `/admin/audit` — list (line 23)

- Purpose: List admin audit entries, newest first (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.AUDIT_READ`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.AuditLogDto>>> list( @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `auditRepo.findAllByOrderByCreatedAtDesc, auditRepo.search`.
- Reachable database/integration operations: `AuditLogRepository.findAllByOrderByCreatedAtDesc, AuditLogRepository.search`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/audit/export` — export (line 36)

- Purpose: Export the audit log (optionally filtered by ?query=) as CSV, newest first, max 10 000 rows (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.AUDIT_READ`.
- Input and return signature: `public ResponseEntity<String> export(@RequestParam(required = false) String query)`.
- Validation helpers: `PageRequest.of`.
- Operations: `auditRepo.findAllByOrderByCreatedAtDesc, auditRepo.search`.
- Reachable database/integration operations: `AuditLogRepository.findAllByOrderByCreatedAtDesc, AuditLogRepository.search`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AuthController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AuthController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/auth/register` — register (line 104)

- Purpose: Register a new user (customer or provider).
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> register( @Valid @RequestBody AuthRequest.Register request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.register`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue, UserRepository.existsByEmailIgnoreCase, UserRepository.existsByPhone, UserRepository.save`.
- Reachable business error keys: `auth.error.admin_registration_blocked, auth.error.email_not_verified, auth.error.email_or_phone_required, auth.error.email_taken, auth.error.invalid_email, auth.error.password_too_long, auth.error.phone_not_verified, auth.error.phone_taken, otp.error.too_many_sends, otp.error.unavailable`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/login` — login (line 113)

- Purpose: Login with email/phone + password.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> login( @Valid @RequestBody AuthRequest.Login request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.login`.
- Reachable database/integration operations: `AuthenticationManager.authenticate, MeterRegistry.counter, ProviderProfileRepository.findByUserId, UserRepository.claimLoginAttempt, UserRepository.clearLoginAttempts, UserRepository.findByLogin, UserRepository.releaseLoginAttempt`.
- Reachable business error keys: `auth.error.too_many_attempts`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/refresh` — refresh (line 134)

- Purpose: Refresh access token.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> refresh( @RequestBody(required = false) AuthRequest.RefreshToken request, @CookieValue(value = ADMIN_REFRESH_COOKIE, required = false) String cookieToken, @RequestHeader(value = CSRF_HEADER, required = false) String requestedWith)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.refreshToken`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, RevokedTokenRepository.existsById, RevokedTokenRepository.saveAndFlush, StringRedisTemplate.hasKey, StringRedisTemplate.opsForValue, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `auth.error.account_disabled, auth.error.token_invalid`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `auth.error.token_invalid; error.access_denied`.

### POST `/auth/logout` — logout (line 154)

- Purpose: Logout and blacklist current JWT tokens.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> logout( @RequestHeader(value = "Authorization", required = false) String authorization, @CookieValue(value = ACCESS_TOKEN_COOKIE, required = false) String cookieToken, @CookieValue(value = ADMIN_REFRESH_COOKIE, required = false) String adminRefreshCookie, @RequestBody(required = false) AuthRequest.Logout request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.logout`.
- Reachable database/integration operations: `RevokedTokenRepository.deleteById, RevokedTokenRepository.existsById, RevokedTokenRepository.findById, RevokedTokenRepository.save, RevokedTokenRepository.saveAndFlush, StringRedisTemplate.opsForValue`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/auth/me` — me (line 177)

- Purpose: Get current authenticated user profile.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> me( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.getCurrentUser, termsAcceptance.isUpToDate`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, TermsAcceptanceRepository.findByUserIdAndType, TermsPolicyRepository.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me` — updateProfile (line 186)

- Purpose: Update profile — fullName, email, profileImageUrl (GAP 3). A new email needs .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> updateProfile( @Valid @RequestBody UpdateProfileRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.confirmPassword, fileStorageService.deletePublic, otpService.sendEmailOtp, userRepo.existsByEmailIgnoreCase, userRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue, TermsAcceptanceRepository.findByUserIdAndType, TermsPolicyRepository.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc, UserRepository.claimLoginAttempt, UserRepository.clearLoginAttempts, UserRepository.existsByEmailIgnoreCase, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.avatar_url_not_allowed, auth.error.email_taken, auth.error.invalid_email, auth.error.too_many_attempts, auth.error.wrong_password, otp.error.too_many_sends, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `auth.error.avatar_url_not_allowed; auth.error.email_taken; auth.error.invalid_email`.

### POST `/auth/me/avatar` — uploadAvatar (line 239)

- Purpose: Upload a profile avatar image (JPEG/PNG/WebP, max 10 MB).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> uploadAvatar( @RequestParam("image") org.springframework.web.multipart.MultipartFile image, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `fileStorageService.deletePublic, fileStorageService.storePublic, limiter.check, userRepo.save`.
- Reachable database/integration operations: `MeterRegistry.counter, ProviderProfileRepository.findByUserId, StringRedisTemplate.execute, TermsAcceptanceRepository.findByUserIdAndType, TermsPolicyRepository.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc, UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `upload.error.empty, upload.error.image_too_large, upload.error.invalid_type, upload.error.storage_failed, upload.error.too_large`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/me/email/verify` — verifyEmail (line 256)

- Purpose: Confirm the email waiting in pendingEmail with the code sent to it. .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> verifyEmail( @Valid @RequestBody AuthRequest.VerifyEmail request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.confirmEmail`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue, UserRepository.existsByEmailIgnoreCase, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.email_taken, auth.error.no_pending_email, otp.error.expired, otp.error.incorrect, otp.error.too_many_attempts, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me/phone` — changePhone (line 266)

- Purpose: Change your phone number — send-otp to the NEW number first, then call this with the code .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> changePhone( @Valid @RequestBody AuthRequest.ChangePhone request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.changePhone`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue, UserRepository.claimLoginAttempt, UserRepository.clearLoginAttempts, UserRepository.existsByPhone, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.phone_taken, auth.error.phone_unchanged, auth.error.too_many_attempts, auth.error.wrong_password, otp.error.expired, otp.error.incorrect, otp.error.too_many_attempts, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me/language` — updateLanguage (line 276)

- Purpose: Update preferred language (EN or AR).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> updateLanguage( @Valid @RequestBody AuthRequest.UpdateLanguage request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.updateLanguage`.
- Reachable database/integration operations: `UserRepository.findByLogin, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me/preferences` — updatePreferences (line 285)

- Purpose: Update search preferences — radius and \.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> updatePreferences( @Valid @RequestBody UpdatePreferencesRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `userRepo.save`.
- Reachable database/integration operations: `UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.radius_min_above_max, auth.error.search_area_coordinates`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `auth.error.radius_min_above_max; auth.error.search_area_coordinates`.

### GET `/auth/me/notification-preferences` — getNotificationPreferences (line 317)

- Purpose: Get notification preferences (channels + quiet hours).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationPreferencesDto>> getNotificationPreferences( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `UserRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me/notification-preferences` — updateNotificationPreferences (line 324)

- Purpose: Update notification preferences (channels + quiet hours).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationPreferencesDto>> updateNotificationPreferences( @Valid @RequestBody com.aiwa.dto.request.UpdateNotificationPreferencesRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `userRepo.save`.
- Reachable database/integration operations: `UserRepository.findById, UserRepository.findByLogin, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/auth/me/push-token` — updatePushToken (line 363)

- Purpose: Register this device's push token (call on login and whenever the OS refreshes it).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> updatePushToken( @Valid @RequestBody com.aiwa.dto.request.UpdatePushTokenRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `pushDevices.register`.
- Reachable database/integration operations: `PushDeviceRepository.findByToken, PushDeviceRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/auth/me/push-token` — clearPushToken (line 373)

- Purpose: Stop pushes to this device (?token=…), or to all of your devices when no token is given .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> clearPushToken( @RequestParam(value = "token", required = false) String token, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `pushDevices.unregister`.
- Reachable database/integration operations: `PushDeviceRepository.deleteByUserId, PushDeviceRepository.deleteByUserIdAndToken, UserRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/send-otp` — sendOtp (line 386)

- Purpose: Send a 6-digit OTP by SMS ({phone}) or by email ({email}). .
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> sendOtp( @Valid @RequestBody OtpRequest.SendOtp request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `otpService.sendEmailOtp, otpService.sendOtp`.
- Reachable database/integration operations: `MeterRegistry.counter, StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue`.
- Reachable business error keys: `otp.error.too_many_sends, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/verify-otp` — verifyOtp (line 401)

- Purpose: Verify OTP ({phone} or {email} + code) — call before /register to confirm ownership.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, String>>> verifyOtp( @Valid @RequestBody OtpRequest.VerifyOtp request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `otpService.verifyEmailOtp, otpService.verifyOtp`.
- Reachable database/integration operations: `StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue`.
- Reachable business error keys: `otp.error.expired, otp.error.incorrect, otp.error.too_many_attempts, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/reset-password` — resetPassword (line 416)

- Purpose: Forgot password — reset with phone or email + OTP code + new password .
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> resetPassword( @Valid @RequestBody AuthRequest.ResetPassword request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.resetPassword`.
- Reachable database/integration operations: `StringRedisTemplate.delete, StringRedisTemplate.execute, StringRedisTemplate.opsForValue, UserRepository.clearLoginAttempts, UserRepository.findByEmailIgnoreCase, UserRepository.findByPhone, UserRepository.save`.
- Reachable business error keys: `auth.error.email_or_phone_required, auth.error.invalid_email, auth.error.password_too_long, otp.error.expired, otp.error.incorrect, otp.error.too_many_attempts, otp.error.unavailable`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/2fa/verify` — verifyMfa (line 430)

- Purpose: Step 2 of login when the account has 2FA enabled — exchange mfaToken + code for a real session.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> verifyMfa( @Valid @RequestBody AuthRequest.VerifyMfa request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.verifyMfa`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, RevokedTokenRepository.existsById, RevokedTokenRepository.saveAndFlush, StringRedisTemplate.execute, StringRedisTemplate.hasKey, StringRedisTemplate.opsForValue, UserRepository.claimLoginAttempt, UserRepository.claimTotpStep, UserRepository.clearLoginAttempts, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `auth.error.account_disabled, auth.error.invalid_totp_code, auth.error.token_invalid, auth.error.too_many_attempts`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/auth/2fa/server-time` — serverTime (line 456)

- Purpose: Server clock — compare against your phone's time when TOTP codes are being rejected.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> serverTime()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `TotpService.driftToleranceSeconds, TotpService.stepSeconds`.
- Reachable database/integration operations: No explicit repository/integration call resolved in this handler; framework auth, helper/ORM behavior and delegates still apply as described in api-flows.md.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/2fa/setup` — setupTotp (line 468)

- Purpose: Start (or restart) 2FA setup — returns a secret to add to an authenticator app. .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.TwoFactorSetupDto>> setupTotp( @Valid @RequestBody AuthRequest.ConfirmIdentity request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.beginTotpSetup`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, UserRepository.claimLoginAttempt, UserRepository.claimTotpStep, UserRepository.clearLoginAttempts, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.invalid_totp_code, auth.error.too_many_attempts, auth.error.totp_setup_not_started, auth.error.wrong_password`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/2fa/enable` — enableTotp (line 478)

- Purpose: Confirm 2FA setup with a code from the authenticator app.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AuthResponse>> enableTotp( @Valid @RequestBody AuthRequest.EnableTotp request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.enableTotp`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, UserRepository.claimTotpStep, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.invalid_totp_code, auth.error.totp_setup_not_started`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/auth/2fa/disable` — disableTotp (line 488)

- Purpose: Turn off 2FA for this account (current password + current code).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> disableTotp( @Valid @RequestBody AuthRequest.ConfirmIdentity request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.disableTotp`.
- Reachable database/integration operations: `UserRepository.claimLoginAttempt, UserRepository.claimTotpStep, UserRepository.clearLoginAttempts, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `auth.error.invalid_totp_code, auth.error.too_many_attempts, auth.error.wrong_password`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/auth/2fa/status` — totpStatus (line 497)

- Purpose: Whether 2FA is currently enabled for this account.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, Boolean>>> totpStatus( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `authService.isTotpEnabled`.
- Reachable database/integration operations: `UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## AvailabilityController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\AvailabilityController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/providers/{providerId}/availability` — get (line 27)

- Purpose: Get a provider's working hours (public).
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.AvailabilityDto>>> get( @PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `availabilityService.getByProvider`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndAvailableTrue`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/availability` — upsert (line 35)

- Purpose: Set/update availability for a day of week (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AvailabilityDto>> upsert( @Valid @RequestBody AvailabilityRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `availabilityService.upsert`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.save, ProviderProfileRepository.findByUserId, StaffMemberRepository.findByIdAndProviderId, UserRepository.findByLogin`.
- Reachable business error keys: `availability.error.invalid_times`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/provider/availability/{id}` — delete (line 46)

- Purpose: Remove an availability entry (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> delete( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `availabilityService.delete`.
- Reachable database/integration operations: `AvailabilityRepository.delete, AvailabilityRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## BookingController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\BookingController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/bookings` — create (line 35)

- Purpose: Create a booking — SCHEDULED or BOOK_NOW (CUSTOMER). .
- URL access: CUSTOMER URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> create( @Valid @RequestBody BookingRequest request, @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.create, bookingService.findByIdempotencyKey`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc, BookingRepository.countByCustomerIdAndStatus, BookingRepository.findActiveForCalendar, BookingRepository.findByCustomerIdAndIdempotencyKey, BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByIdForUpdate, PushDeviceRepository.findByUserId, SavedAddressRepository.findById, ServiceRepository.findById, StaffMemberRepository.findByIdAndProviderId, StringRedisTemplate.delete, StringRedisTemplate.opsForValue, TermsAcceptanceRepository.findByUserIdAndType, TermsPolicyRepository.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc, UserRepository.findById, UserRepository.findByLogin, UserRepository.lockById`.
- Reachable business error keys: `booking.error.address_required, booking.error.address_wrong_customer, booking.error.conflict, booking.error.date_time_required, booking.error.duplicate, booking.error.idempotency_key_reused, booking.error.no_book_now_slots, booking.error.outside_service_radius, booking.error.outside_working_hours, booking.error.own_listing, booking.error.provider_not_working, booking.error.provider_unavailable_today, booking.error.slot_in_past, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.too_far_ahead, booking.error.too_many_pending, terms.error.not_accepted`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/bookings/{id}` — getById (line 60)

- Purpose: Get booking by ID.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> getById( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.getById`.
- Reachable database/integration operations: `BookingRepository.countByCustomerId, BookingRepository.findById, PlatformSettingsRepository.findFirstByOrderByIdAsc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/bookings/my` — myBookings (line 69)

- Purpose: Get current customer's bookings, newest first — optional status filter, .
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> myBookings( @RequestParam(required = false) List<BookingStatus> status, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.getMyBookings`.
- Reachable database/integration operations: `BookingRepository.findByCustomerIdAndStatusInOrderByCreatedAtDesc, BookingRepository.findByCustomerIdOrderByCreatedAtDesc, PlatformSettingsRepository.findFirstByOrderByIdAsc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/bookings/provider` — providerBookings (line 81)

- Purpose: Get the authenticated provider's bookings — optional status filter .
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.BookingDto>>> providerBookings( @RequestParam(required = false) List<BookingStatus> status, @RequestParam(defaultValue = "asc") String order, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.getProviderBookings`.
- Reachable database/integration operations: `BookingRepository.findByProviderIdAndStatusInOrderByBookingDateAscStartTimeAsc, BookingRepository.findByProviderIdAndStatusInOrderByBookingDateDescStartTimeDesc, BookingRepository.findByProviderIdOrderByBookingDateAscStartTimeAsc, BookingRepository.findByProviderIdOrderByBookingDateDescStartTimeDesc, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/bookings/{id}/contact` — contact (line 96)

- Purpose: The other party's phone for the Call button — only while the booking is .
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingContactDto>> contact( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.getContact`.
- Reachable database/integration operations: `BookingRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.contact_no_phone, booking.error.contact_not_available`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/accept` — accept (line 108)

- Purpose: Provider accepts a pending booking.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> accept( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/cancel` — cancel (line 117)

- Purpose: Cancel a booking (customer or provider) with an optional reason.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> cancel( @PathVariable Long id, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/reject` — reject (line 129)

- Purpose: Provider rejects booking with reason + returns alternative providers.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingWithAlternativesDto>> reject( @PathVariable Long id, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `bookingService.rejectWithAlternatives`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findNearby, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.invalid_transition, booking.error.reason_required`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/on-the-way` — onTheWay (line 141)

- Purpose: Provider marks ON_THE_WAY.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> onTheWay( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/arrived` — arrived (line 150)

- Purpose: Provider marks ARRIVED.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> arrived( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/in-progress` — inProgress (line 159)

- Purpose: Provider marks IN_PROGRESS.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> inProgress( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/complete` — complete (line 168)

- Purpose: Provider marks booking COMPLETED — cashCollected=false flags it DISPUTED; .
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> complete( @PathVariable Long id, @RequestParam(defaultValue = "true") boolean cashCollected, @RequestParam(required = false) String note, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `bookingService.complete`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.only_provider_complete, booking.error.quote_pending, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/no-show` — noShow (line 182)

- Purpose: Provider marks booking as NO_SHOW (customer did not attend).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> noShow( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.updateStatus`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, MeterRegistry.counter, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.customer_checked_in, booking.error.expired_is_automatic, booking.error.home_visit_steps, booking.error.invalid_transition, booking.error.no_show_too_early, booking.error.only_provider_complete, booking.error.only_provider_update_status, booking.error.quote_pending, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_early_for_step, booking.error.venue_no_travel`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/reschedule` — reschedule (line 191)

- Purpose: Customer reschedules a booking to a new date/time.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> reschedule( @PathVariable Long id, @Valid @RequestBody RescheduleRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.reschedule`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc, BookingRepository.findActiveForCalendar, BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByIdForUpdate, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.conflict, booking.error.only_customer_reschedule, booking.error.outside_working_hours, booking.error.provider_not_working, booking.error.reschedule_requires_pending_or_accepted, booking.error.slot_in_past, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_far_ahead`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/destination` — amendDestination (line 201)

- Purpose: Customer moves a home visit to another saved address (provider must confirm again).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> amendDestination( @PathVariable Long id, @Valid @RequestBody com.aiwa.dto.request.AmendDestinationRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.amendDestination`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByIdForUpdate, PushDeviceRepository.findByUserId, SavedAddressRepository.findById, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.address_wrong_customer, booking.error.destination_home_service_only, booking.error.only_customer_reschedule, booking.error.outside_service_radius, booking.error.reschedule_requires_pending_or_accepted`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/propose-time` — proposeTime (line 211)

- Purpose: Provider proposes an alternative slot for a PENDING booking.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> proposeTime( @PathVariable Long id, @Valid @RequestBody RescheduleRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.proposeReschedule`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc, BookingRepository.findActiveForCalendar, BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByIdForUpdate, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.conflict, booking.error.only_provider_propose, booking.error.outside_working_hours, booking.error.propose_requires_pending, booking.error.provider_not_working, booking.error.slot_in_past, booking.error.too_far_ahead`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/proposal-response` — proposalResponse (line 221)

- Purpose: Customer accepts or declines the provider-proposed time.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> proposalResponse( @PathVariable Long id, @RequestParam boolean accept, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.respondToProposal`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc, BookingRepository.findActiveForCalendar, BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByIdForUpdate, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.conflict, booking.error.no_proposal, booking.error.not_awaiting_confirmation, booking.error.only_customer_respond_proposal, booking.error.outside_working_hours, booking.error.proposal_lapsed, booking.error.provider_not_working, booking.error.slot_in_past, booking.error.staff_not_offering_service, booking.error.staff_unavailable, booking.error.start_passed, booking.error.too_far_ahead`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/travel-fee-quote` — quoteTravelFee (line 232)

- Purpose: Provider quotes a travel fee for this home-service booking (customer must accept).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> quoteTravelFee( @PathVariable Long id, @RequestParam BigDecimal amount, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.quoteTravelFee`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.quote_home_service_only, booking.error.quote_invalid_amount, booking.error.quote_locked, booking.error.quote_not_allowed_now`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/travel-fee-response` — travelFeeResponse (line 242)

- Purpose: Customer accepts (fee applied to the total) or declines (booking cancelled) a travel quote.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> travelFeeResponse( @PathVariable Long id, @RequestParam boolean accept, @RequestParam(required = false) BigDecimal amount, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.respondToTravelFeeQuote`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.no_pending_quote, booking.error.quote_changed, booking.error.quote_not_allowed_now`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/contest-no-show` — contestNoShow (line 254)

- Purpose: Customer contests a no-show within 48 h of the booking; opens a payment dispute (AU-03).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> contestNoShow( @PathVariable Long id, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.bounded, FreeTextBody.pick`.
- Operations: `bookingService.contestNoShow`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.no_show_already_contested, booking.error.no_show_contest_closed, booking.error.not_no_show`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/check-in` — checkIn (line 265)

- Purpose: Customer checks in at an on-site (venue) booking.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> checkIn( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.checkIn`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `booking.error.already_checked_in, booking.error.checkin_onsite_only, booking.error.checkin_requires_accepted, booking.error.checkin_too_early, booking.error.checkin_too_late, booking.error.only_customer_checkin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/bookings/{id}/confirm-payment` — confirmPayment (line 274)

- Purpose: Customer confirms cash paid (paid=true) or reports unpaid/disputed (paid=false).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.BookingDto>> confirmPayment( @PathVariable Long id, @RequestParam boolean paid, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.confirmPayment`.
- Reachable database/integration operations: `BookingRepository.findById, BookingRepository.save, CommissionLedgerRepository.existsByBookingId, CommissionLedgerRepository.findByBookingId, CommissionLedgerRepository.save, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `booking.error.only_customer_confirm_payment, booking.error.payment_already_resolved, booking.error.payment_confirm_requires_completed, booking.error.payment_dispute_already_reported, booking.error.payment_dispute_window_closed`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/bookings/slots` — slots (line 285)

- Purpose: Get available time slots for a provider + service on a date.
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.TimeSlotDto>>> slots( @RequestParam Long providerId, @RequestParam Long serviceId, @RequestParam(required = false) Long staffMemberId, @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `bookingService.getAvailableSlots`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdAndStaffMemberIdAndDayOfWeek, AvailabilityRepository.findByProviderIdAndStaffMemberIsNullAndDayOfWeek, AvailabilityRepository.findFirstByProviderIdAndDayOfWeekOrderByStartTimeAsc, BookingRepository.findActiveForCalendar, ServiceRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## ChatController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ChatController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/bookings/{bookingId}/chat` — list (line 42)

- Purpose: list.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.ChatMessageDto>>> list( @PathVariable Long bookingId, @RequestParam(required = false) Long afterId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `chatRepo.findByBookingIdAndIdGreaterThanOrderByIdAsc, chatRepo.findByBookingIdOrderByCreatedAtAsc`.
- Reachable database/integration operations: `BookingRepository.findById, ChatMessageRepository.findByBookingIdAndIdGreaterThanOrderByIdAsc, ChatMessageRepository.findByBookingIdOrderByCreatedAtAsc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/bookings/{bookingId}/chat` — send (line 57)

- Purpose: send.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ChatMessageDto>> send( @PathVariable Long bookingId, @Valid @RequestBody ChatMessageRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `chatRepo.save, limiter.check, notificationService.send`.
- Reachable database/integration operations: `BookingRepository.findById, ChatMessageRepository.save, MeterRegistry.counter, NotificationRepository.save, PushDeviceRepository.findByUserId, StringRedisTemplate.execute, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `chat.error.closed`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `chat.error.closed`.

### POST `/bookings/{bookingId}/chat/{messageId}/report` — report (line 93)

- Purpose: Report an abusive/inappropriate chat message (either party to the booking).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> report( @PathVariable Long bookingId, @PathVariable Long messageId, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findById, ChatMessageRepository.findById, MeterRegistry.counter, ModerationCaseRepository.existsByStatusAndTargetTypeAndTargetId, ModerationCaseRepository.save, StringRedisTemplate.execute, UserRepository.findByLogin`.
- Reachable business error keys: `chat.error.wrong_booking`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/chat/moderation` — reportedMessages (line 133)

- Purpose: Reported chat messages awaiting moderation, with the report reason (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.ChatModerationDto>>> reportedMessages( @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "200") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `chatRepo.findById, moderationRepo.searchChat`.
- Reachable database/integration operations: `ChatMessageRepository.findById, ModerationCaseRepository.searchChat`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/chat/moderation/{caseId}/resolve` — resolveReported (line 163)

- Purpose: Resolve a reported chat message: REMOVE (redact for both parties) / KEEP (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> resolveReported( @PathVariable Long caseId, @RequestParam String action)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, chatRepo.findById, chatRepo.save, moderationRepo.findById, moderationRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, ChatMessageRepository.findById, ChatMessageRepository.save, ModerationCaseRepository.findById, ModerationCaseRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Unknown action: `.

## ComplaintController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ComplaintController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/complaints` — submit (line 34)

- Purpose: Submit a complaint.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ComplaintDto>> submit( @RequestParam(required = false) Long targetProviderId, @RequestParam(required = false) Long bookingId, @RequestParam String category, @RequestParam(required = false) String description, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `complaintService.submit, limiter.check`.
- Reachable database/integration operations: `BookingRepository.findById, ComplaintRepository.save, MeterRegistry.counter, ProviderProfileRepository.findById, StringRedisTemplate.execute, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `complaint.error.category_invalid, complaint.error.description_invalid`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/complaints/my` — my (line 52)

- Purpose: Get my complaints.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> my( @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `Pages.of`.
- Operations: `complaintService.getMyComplaints`.
- Reachable database/integration operations: `ComplaintRepository.findOwnReports, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/complaints` — adminList (line 62)

- Purpose: List all complaints (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ComplaintDto>>> adminList( @RequestParam(required = false) ComplaintStatus status, @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `complaintService.adminSearch`.
- Reachable database/integration operations: `ComplaintRepository.searchAll, ComplaintRepository.searchByStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/complaints/{id}/resolve` — resolve (line 74)

- Purpose: Resolve a complaint (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ComplaintDto>> resolve( @PathVariable Long id, @RequestParam(required = false) String notes, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `auditService.record, complaintService.resolve`.
- Reachable database/integration operations: `AuditLogRepository.save, ComplaintRepository.findById, ComplaintRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/complaints/{id}/flag` — flag (line 88)

- Purpose: Flag a complaint for escalation (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> flag(@PathVariable Long id)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, complaintService.flag`.
- Reachable database/integration operations: `AuditLogRepository.save, ComplaintRepository.findById, ComplaintRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/users/{userId}/flag` — flagUser (line 98)

- Purpose: Flag a user for review (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> flagUser( @PathVariable Long userId, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `complaintService.flagUser`.
- Reachable database/integration operations: `ComplaintRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/users/{userId}/warn` — warnUser (line 112)

- Purpose: Send a warning to a user (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> warnUser( @PathVariable Long userId, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `auditService.record, notificationService.send, userRepo.findById`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## DevTotpResetController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\DevTotpResetController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/dev/2fa/reset` — reset (line 50)

- Purpose: Wipe 2FA for the account with this email/phone — local dev only, does not issue any code.
- URL access: Public URL filter (controller applies token/password checks where required). Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> reset( @RequestParam String identifier)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `userRepo.findByLogin, userRepo.save`.
- Reachable database/integration operations: `UserRepository.findByLogin, UserRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## GalleryController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\GalleryController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/provider/gallery` — upload (line 48)

- Purpose: Upload a gallery image (PROVIDER role) — returns the provider's image URLs.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<String>>> upload( @RequestParam("image") MultipartFile image, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `fileStorageService.storePublic, galleryRepo.countByProviderId, galleryRepo.save, limiter.check`.
- Reachable database/integration operations: `GalleryImageRepository.countByProviderId, GalleryImageRepository.findByProviderIdOrderByIdAsc, GalleryImageRepository.save, MeterRegistry.counter, ProviderProfileRepository.findByUserId, StringRedisTemplate.execute, UserRepository.findByLogin`.
- Reachable business error keys: `gallery.error.max_images, upload.error.empty, upload.error.image_too_large, upload.error.invalid_type, upload.error.storage_failed, upload.error.too_large`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `gallery.error.max_images`.

### DELETE `/provider/gallery` — remove (line 69)

- Purpose: Remove one of your gallery images by URL (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<String>>> remove( @RequestParam String imageUrl, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `galleryRepo.findByProviderIdOrderByIdAsc`.
- Reachable database/integration operations: `GalleryImageRepository.delete, GalleryImageRepository.findByProviderIdOrderByIdAsc, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/provider/gallery/{providerId}` — provider (line 86)

- Purpose: provider.
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public gallery of a provider (hidden images excluded)") public ResponseEntity<ApiResponse.Success<List<String>>> getGallery( @PathVariable Long providerId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `galleryRepo.findByProviderIdOrderByIdAsc, providerRepo.findById`.
- Reachable database/integration operations: `GalleryImageRepository.findByProviderIdOrderByIdAsc, ProviderProfileRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Provider`.

### GET `/provider/gallery-images` — mine (line 109)

- Purpose: Your gallery with image ids and moderation state (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.GalleryImageDto>>> mine( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `galleryRepo.findByProviderIdOrderByIdAsc`.
- Reachable database/integration operations: `GalleryImageRepository.findByProviderIdOrderByIdAsc, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/provider/gallery-images/{imageId}` — removeById (line 120)

- Purpose: Remove one of your gallery images by id (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> removeById( @PathVariable Long imageId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `galleryRepo.findByIdAndProviderId`.
- Reachable database/integration operations: `GalleryImageRepository.delete, GalleryImageRepository.findByIdAndProviderId, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/providers/{providerId}/gallery/{imageId}/report` — report (line 134)

- Purpose: Report a gallery photo for moderation (any signed-in user).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> report( @PathVariable Long providerId, @PathVariable Long imageId, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `galleryRepo.findByIdAndProviderId, moderationRepo.existsByStatusAndTargetTypeAndTargetId, moderationRepo.save`.
- Reachable database/integration operations: `GalleryImageRepository.findByIdAndProviderId, ModerationCaseRepository.existsByStatusAndTargetTypeAndTargetId, ModerationCaseRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## ModerationController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ModerationController.java`. Class authorization: `"hasRole('ADMIN')"`.

### GET `/admin/moderation` — list (line 34)

- Purpose: list.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.ModerationCaseDto>>> list( @RequestParam(defaultValue = "OPEN") ModerationStatus status, @RequestParam(required = false) ModerationTargetType type, @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "200") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `moderationRepo.searchByReason, moderationRepo.searchChat, moderationRepo.searchImages, moderationRepo.searchReviews`.
- Reachable database/integration operations: `GalleryImageRepository.findById, ModerationCaseRepository.searchByReason, ModerationCaseRepository.searchChat, ModerationCaseRepository.searchImages, ModerationCaseRepository.searchReviews`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/moderation` — create (line 53)

- Purpose: create.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ModerationCaseDto>> create( @Valid @RequestBody ModerationRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `moderationRepo.save`.
- Reachable database/integration operations: `GalleryImageRepository.findById, ModerationCaseRepository.save, UserRepository.findByLogin`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/moderation/{id}/action` — action (line 76)

- Purpose: action.
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ModerationCaseDto>> action( @PathVariable Long id, @RequestParam ModerationStatus status, @RequestParam(required = false) String notes, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.bounded, FreeTextBody.pick`.
- Operations: `auditService.record, galleryRepo.findById, galleryRepo.save, moderationRepo.findById, moderationRepo.save, notificationService.send`.
- Reachable database/integration operations: `AuditLogRepository.save, GalleryImageRepository.findById, GalleryImageRepository.save, ModerationCaseRepository.findById, ModerationCaseRepository.save, NotificationRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## NotificationController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\NotificationController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/notifications` — getMyNotifications (line 25)

- Purpose: Get my notifications (paginated).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.NotificationDto>>> getMyNotifications( @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `Pages.of`.
- Operations: `notificationService.getMyNotifications`.
- Reachable database/integration operations: `NotificationRepository.findByUserIdOrderByCreatedAtDesc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/notifications/unread-count` — unreadCount (line 37)

- Purpose: Get unread notification count.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Long>> unreadCount( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `notificationService.countUnread`.
- Reachable database/integration operations: `NotificationRepository.countByUserIdAndReadFalse, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/notifications/mark-all-read` — markAllRead (line 45)

- Purpose: Mark all notifications as read.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> markAllRead( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `notificationService.markAllRead`.
- Reachable database/integration operations: `NotificationRepository.markAllReadForUser, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH, PUT `/notifications/{id}/read` — markRead (line 57)

- Purpose: Mark one of my notifications as read.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.NotificationDto>> markRead( @PathVariable Long id, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `notificationService.markRead`.
- Reachable database/integration operations: `NotificationRepository.findByIdAndUserId, NotificationRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## ProviderController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ProviderController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/providers/nearby` — getNearby (line 30)

- Purpose: Discover nearby providers (location-based) — sort: distance|rating|price.
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderSummaryDto>>> getNearby( @RequestParam double lat, @RequestParam double lng, @RequestParam(defaultValue = "10") double radiusKm, @RequestParam(required = false) ServiceCategory category, @RequestParam(defaultValue = "distance") String sort, @RequestParam(required = false) java.math.BigDecimal maxPrice, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.getNearby`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, ProviderProfileRepository.findAllById, ProviderProfileRepository.findNearby, ProviderProfileRepository.findNearbyByCategory, ServiceRepository.minActivePriceByProvider, StringRedisTemplate.opsForValue`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/providers/search` — search (line 46)

- Purpose: Search providers by name.
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderSummaryDto>>> search( @RequestParam(defaultValue = "") String q, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.search`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, ProviderProfileRepository.searchByName, ServiceRepository.minActivePriceByProvider`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/providers/{id}` — getById (line 57)

- Purpose: Get full provider profile with services and reviews .
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> getById( @PathVariable Long id, @RequestParam(required = false) Double lat, @RequestParam(required = false) Double lng, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.getById`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.existsByCustomerIdAndProviderIdAndStatusIn, BookingRepository.findBusyProviderIds, ProviderProfileRepository.findById, ServiceRepository.minActivePriceByProvider, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/providers/waitlist` — joinWaitlist (line 72)

- Purpose: \.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> joinWaitlist( @RequestParam(required = false) ServiceCategory category, @RequestParam(required = false) Double lat, @RequestParam(required = false) Double lng, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `userRepo.findByLogin, waitlistService.join`.
- Reachable database/integration operations: `ProviderWaitlistRepository.existsByUserIdAndCategoryAndNotifiedAtIsNull, ProviderWaitlistRepository.existsByUserIdAndCategoryIsNullAndNotifiedAtIsNull, ProviderWaitlistRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/profile` — createProfile (line 92)

- Purpose: Create provider profile (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> createProfile( @Valid @RequestBody ProviderProfileRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.createProfile`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, ServiceRepository.minActivePriceByProvider, UserRepository.findById, UserRepository.findByLogin`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PUT `/provider/profile` — updateProfile (line 103)

- Purpose: Update provider profile (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ProviderDetailDto>> updateProfile( @Valid @RequestBody ProviderProfileRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.updateProfile`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, ServiceRepository.minActivePriceByProvider, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/provider/dashboard` — getDashboard (line 113)

- Purpose: Get provider dashboard stats (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.DashboardDto>> getDashboard( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.getDashboard`.
- Reachable database/integration operations: `BookingRepository.countByProviderAndStatus, BookingRepository.findByProviderIdAndBookingDate, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## ProviderModeController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ProviderModeController.java`. Class authorization: `"hasRole('PROVIDER')"`.

### PATCH `/provider/mode` — updateMode (line 23)

- Purpose: updateMode.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ApiResponse.Success<Void> updateMode( @RequestParam(required = false) Boolean vacationMode, @RequestParam(required = false) Boolean offlineMode, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId, providerRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/provider/mode/travel-fee` — updateTravelFee (line 41)

- Purpose: updateTravelFee.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ApiResponse.Success<Void> updateTravelFee( @RequestParam(required = false) java.math.BigDecimal amount, @RequestParam(required = false, defaultValue = "false") boolean clear, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId, providerRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `provider.travel_fee.must_be_non_negative; provider.travel_fee.too_large`.

### PATCH `/provider/mode/service-radius` — updateServiceRadius (line 64)

- Purpose: updateServiceRadius.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ApiResponse.Success<ApiResponse.ProviderDetailDto> updateServiceRadius( @RequestParam(required = false) Double km, @RequestParam(required = false, defaultValue = "false") boolean clear, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerService.updateServiceRadius`.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, ServiceRepository.minActivePriceByProvider, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `provider.service_radius.invalid`.

### PATCH `/provider/mode/travel-buffer` — updateTravelBuffer (line 81)

- Purpose: updateTravelBuffer.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ApiResponse.Success<Void> updateTravelBuffer( @RequestParam int minutes, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId, providerRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `provider.travel_buffer.invalid`.

## ReviewController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ReviewController.java`. Class authorization: none; URL filter and service checks apply.

### POST `/reviews` — create (line 29)

- Purpose: Submit a review for a completed booking.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> create( @Valid @RequestBody ReviewRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `reviewService.create`.
- Reachable database/integration operations: `BookingRepository.findById, NotificationRepository.save, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, ReviewRepository.calculateAverageRating, ReviewRepository.countVisibleForProvider, ReviewRepository.existsByBookingIdAndDirection, ReviewRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `review.error.already_reviewed, review.error.not_completed, review.error.not_your_booking`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/providers/{providerId}/reviews` — getByProvider (line 40)

- Purpose: Customer reviews of a provider (public, paginated, with the provider's replies).
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> getByProvider( @PathVariable Long providerId, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `reviewService.getByProvider`.
- Reachable database/integration operations: `ReviewRepository.findByProviderIdAndDirectionAndHiddenFalseOrderByCreatedAtDesc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/reviews/my` — mine (line 51)

- Purpose: Reviews I have written (totalElements = my review count).
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ReviewDto>>> mine( @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `reviewService.getMine`.
- Reachable database/integration operations: `ReviewRepository.findByUserIdOrderByCreatedAtDesc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/reviews/{id}/reply` — reply (line 61)

- Purpose: Reply publicly to a customer review of your business (PROVIDER); sending again edits the reply.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> reply( @PathVariable Long id, @RequestBody java.util.Map<String, String> body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `reviewService.reply`.
- Reachable database/integration operations: `NotificationRepository.save, PushDeviceRepository.findByUserId, ReviewRepository.findById, ReviewRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `review.error.reply_customer_reviews_only, review.error.reply_empty, review.error.reply_too_long`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/reviews/{id}/visibility` — setVisibility (line 77)

- Purpose: Hide or unhide a review; recomputes the provider rating (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ReviewDto>> setVisibility( @PathVariable Long id, @RequestParam boolean hidden)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, reviewService.setVisibility`.
- Reachable database/integration operations: `AuditLogRepository.save, ProviderProfileRepository.save, ReviewRepository.calculateAverageRating, ReviewRepository.countVisibleForProvider, ReviewRepository.findById, ReviewRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/reviews/moderation` — reportedReviews (line 88)

- Purpose: Reported reviews awaiting moderation, with the report reason (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.ReviewModerationDto>>> reportedReviews( @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "200") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `moderationRepo.searchReviews, reviewRepo.findById`.
- Reachable database/integration operations: `ModerationCaseRepository.searchReviews, ReviewRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/reviews/moderation/{caseId}/resolve` — resolveReported (line 119)

- Purpose: Resolve a reported-review case: REMOVE (hide + recompute) / HIDE / KEEP (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> resolveReported( @PathVariable Long caseId, @RequestParam String action)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, moderationRepo.findById, moderationRepo.save, reviewService.setVisibility`.
- Reachable database/integration operations: `AuditLogRepository.save, ModerationCaseRepository.findById, ModerationCaseRepository.save, ProviderProfileRepository.save, ReviewRepository.calculateAverageRating, ReviewRepository.countVisibleForProvider, ReviewRepository.findById, ReviewRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Unknown action: `.

## SafetyController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SafetyController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/bookings/{bookingId}/safety` — events (line 31)

- Purpose: Safety timeline of a booking (the other party's SOS events are not shown).
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.SafetyEventDto>>> events( @PathVariable Long bookingId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `safetyService.events`.
- Reachable database/integration operations: `BookingRepository.findById, SafetyEventRepository.findByBookingIdOrderByCreatedAtAsc, SosDeliveryRepository.findByEventIdOrderByIdAsc, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/bookings/{bookingId}/safety` — record (line 40)

- Purpose: Record a safety event. type=SOS alerts support (push + SMS) and your trusted contacts; .
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SafetyEventDto>> record( @PathVariable Long bookingId, @Valid @RequestBody SafetyEventRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `safetyService.record`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findById, MeterRegistry.counter, NotificationRepository.save, PushDeviceRepository.findByUserId, SafetyEventRepository.countByActorIdAndTypeAndCreatedAtAfter, SafetyEventRepository.findFirstByBookingIdAndActorIdAndTypeAndResolvedFalseOrderByCreatedAtDesc, SafetyEventRepository.save, SosDeliveryRepository.findByEventIdOrderByIdAsc, SosDeliveryRepository.save, TrustedContactRepository.findByUserIdOrderByCreatedAtAsc, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `safety.error.sos_not_live`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/bookings/{bookingId}/safety/{eventId}/resolve` — resolveOwn (line 52)

- Purpose: \.
- URL access: CUSTOMER / PROVIDER / ADMIN URL filter; participant ownership in service. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SafetyEventDto>> resolveOwn( @PathVariable Long bookingId, @PathVariable Long eventId, @RequestParam(required = false) String notes, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.pick`.
- Operations: `safetyService.resolveOwn`.
- Reachable database/integration operations: `NotificationRepository.save, PushDeviceRepository.findByUserId, SafetyEventRepository.findByIdAndBookingId, SafetyEventRepository.save, TrustedContactRepository.findByUserIdOrderByCreatedAtAsc, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `safety.error.not_sos`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/safety` — queue (line 67)

- Purpose: SOS queue — status OPEN (default) | RESOLVED | ALL (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.AdminSafetyEventDto>>> queue( @RequestParam(defaultValue = "OPEN") String status, @RequestParam(required = false) String query, @RequestParam(defaultValue = "newest") String order, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `PageRequest.of`.
- Operations: `safetyService.adminQueue`.
- Reachable database/integration operations: `SafetyEventRepository.search, SosDeliveryRepository.findByEventIdInOrderByIdAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/safety/{eventId}/resolve` — adminResolve (line 80)

- Purpose: Close an SOS with a note of what was done (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.AdminSafetyEventDto>> adminResolve( @PathVariable Long eventId, @RequestParam(required = false) String notes, @RequestBody(required = false) FreeTextBody body, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `FreeTextBody.require`.
- Operations: `safetyService.adminResolve`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, PushDeviceRepository.findByUserId, SafetyEventRepository.findById, SafetyEventRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `safety.error.not_sos, safety.error.notes_required`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## SavedController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SavedController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/users/me/saved` — list (line 31)

- Purpose: List all saved providers for the current customer.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.ProviderSummaryDto>>> list( @AuthenticationPrincipal UserDetails userDetails, @RequestParam(required = false) Double lat, @RequestParam(required = false) Double lng)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `AvailabilityRepository.findByProviderIdInAndDayOfWeekAndAvailableTrue, BookingRepository.findBusyProviderIds, SavedProviderRepository.findByUserIdOrderByCreatedAtDesc, ServiceRepository.minActivePriceByProvider, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/users/me/saved/{providerId}` — save (line 51)

- Purpose: Save (heart) a provider.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> save( @PathVariable Long providerId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findById, savedRepo.existsByUserIdAndProviderId, savedRepo.save, userRepo.findById`.
- Reachable database/integration operations: `ProviderProfileRepository.findById, SavedProviderRepository.existsByUserIdAndProviderId, SavedProviderRepository.save, UserRepository.findById, UserRepository.findByLogin`.
- Reachable business error keys: `saved.error.already_saved`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `saved.error.already_saved`.

### DELETE `/users/me/saved/{providerId}` — unsave (line 72)

- Purpose: Unsave (un-heart) a provider.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> unsave( @PathVariable Long providerId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `savedRepo.deleteByUserIdAndProviderId`.
- Reachable database/integration operations: `SavedProviderRepository.deleteByUserIdAndProviderId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/users/me/saved/{providerId}/check` — check (line 84)

- Purpose: Check if a provider is saved by current user — returns boolean.
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Boolean>> check( @PathVariable Long providerId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `savedRepo.existsByUserIdAndProviderId`.
- Reachable database/integration operations: `SavedProviderRepository.existsByUserIdAndProviderId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## ServiceController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\ServiceController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/providers/{providerId}/services` — list (line 27)

- Purpose: List active services for a provider (public).
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.ServiceDto>>> list( @PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `serviceManagementService.getByProvider`.
- Reachable database/integration operations: `ServiceRepository.findByProviderIdAndActiveTrue`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/services` — create (line 35)

- Purpose: Add a service (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ServiceDto>> create( @Valid @RequestBody ServiceRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `serviceManagementService.create`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ServiceRepository.save, UserRepository.findByLogin`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PUT `/provider/services/{serviceId}` — update (line 46)

- Purpose: Update a service (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.ServiceDto>> update( @PathVariable Long serviceId, @Valid @RequestBody ServiceRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `serviceManagementService.update`.
- Reachable database/integration operations: `ServiceRepository.findById, ServiceRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### DELETE `/provider/services/{serviceId}` — delete (line 57)

- Purpose: Delete (deactivate) a service (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> delete( @PathVariable Long serviceId, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `serviceManagementService.delete`.
- Reachable database/integration operations: `ServiceRepository.findById, ServiceRepository.save, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## SettlementController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SettlementController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/provider/settlement` — providerSettlement (line 36)

- Purpose: providerSettlement.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementSummaryDto>> providerSettlement( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId`.
- Reachable database/integration operations: `CommissionLedgerRepository.findByProviderIdOrderByCreatedAtDesc, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByUserId, UserRepository.findByLogin`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/provider/settlement/pay` — payDues (line 57)

- Purpose: payDues.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementSummaryDto>> payDues( @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, ledgerRepo.findByProviderIdAndStatusIn, notificationService.send, providerRepo.findByUserId, providerRepo.save, userRepo.findByRoleAndActive`.
- Reachable database/integration operations: `AuditLogRepository.save, CommissionLedgerRepository.findByProviderIdAndStatusIn, CommissionLedgerRepository.findByProviderIdOrderByCreatedAtDesc, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById, UserRepository.findByLogin, UserRepository.findByRoleAndActive`.
- Reachable business error keys: `settlement.error.nothing_to_settle, settlement.error.report_pending`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `settlement.error.nothing_to_settle; settlement.error.report_pending`.

### GET `/admin/settlements` — dueEntries (line 100)

- Purpose: dueEntries.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE_READ`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.CommissionLedgerDto>>> dueEntries( @RequestParam(defaultValue = "DUE") LedgerEntryStatus status, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "200") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `CommissionLedgerRepository.findByStatusOrderByCreatedAtAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/settlements/overview` — overview (line 114)

- Purpose: overview.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE_READ`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementOverviewDto>> overview()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `ledgerRepo.countDistinctProvidersByStatusIn, ledgerRepo.sumByStatusIn, platformSettings.getCommissionPercent`.
- Reachable database/integration operations: `CommissionLedgerRepository.countDistinctProvidersByStatusIn, CommissionLedgerRepository.sumByStatusIn, PlatformSettingsRepository.findFirstByOrderByIdAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/settlements/providers` — providers (line 128)

- Purpose: providers.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE_READ`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<org.springframework.data.domain.Page<ApiResponse.SettlementRowDto>>> providers( @RequestParam(required = false) String query, @RequestParam(defaultValue = "ALL") String status, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "200") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `CommissionLedgerRepository.searchProviderTotals, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findAllById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Unknown status: `.

### GET `/admin/settlements/provider/{providerId}` — providerDetail (line 145)

- Purpose: providerDetail.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE_READ`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementDetailDto>> providerDetail( @PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `ledgerRepo.findByProviderIdOrderByCreatedAtDesc, platformSettings.getCommissionPercent, platformSettings.getCommissionPercentFor, providerRepo.findById`.
- Reachable database/integration operations: `CommissionLedgerRepository.findByProviderIdOrderByCreatedAtDesc, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/settlements/provider/{providerId}/payout-report` — payoutReport (line 185)

- Purpose: payoutReport.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<java.util.Map<String, Object>>> payoutReport(@PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findById`.
- Reachable database/integration operations: `CommissionLedgerRepository.findByProviderIdAndStatusIn, ProviderProfileRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/settlements/provider/{providerId}/confirm-payout` — confirmPayout (line 208)

- Purpose: confirmPayout.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SettlementDetailDto>> confirmPayout( @PathVariable Long providerId, @RequestParam(required = false) BigDecimal expectedAmount)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, ledgerRepo.saveAll, notificationService.send, providerRepo.findById, providerRepo.save, settlementService.mayResumeBookings`.
- Reachable database/integration operations: `AuditLogRepository.save, CommissionLedgerRepository.findByProviderIdAndStatusIn, CommissionLedgerRepository.findByProviderIdOrderByCreatedAtDesc, CommissionLedgerRepository.saveAll, NotificationRepository.save, PlatformSettingsRepository.findFirstByOrderByIdAsc, ProviderProfileRepository.findById, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `settlement.error.amount_mismatch, settlement.error.amount_required`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `No outstanding balance for this provider; settlement.error.amount_mismatch; settlement.error.amount_required`.

### GET `/admin/settlements/export` — exportLedger (line 248)

- Purpose: exportLedger.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE_READ`.
- Input and return signature: `public ResponseEntity<org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody> exportLedger()`.
- Validation helpers: `PageRequest.of`.
- Operations: `ledgerRepo.findAllByOrderByIdDesc`.
- Reachable database/integration operations: `CommissionLedgerRepository.findAllByOrderByIdDesc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/settlements/provider/{providerId}/remind` — sendOverdueReminder (line 276)

- Purpose: sendOverdueReminder.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> sendOverdueReminder(@PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `ledgerRepo.findByProviderIdAndStatusIn, notificationService.send, providerRepo.findById`.
- Reachable database/integration operations: `CommissionLedgerRepository.findByProviderIdAndStatusIn, NotificationRepository.save, ProviderProfileRepository.findById, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/settlements/{id}/settle` — settle (line 295)

- Purpose: settle.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.CommissionLedgerDto>> settle( @PathVariable Long id, @RequestParam(required = false) BigDecimal expectedAmount, @RequestParam(required = false) String reference)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, ledgerRepo.findById, ledgerRepo.save, notificationService.send, providerRepo.save, settlementService.mayResumeBookings`.
- Reachable database/integration operations: `AuditLogRepository.save, CommissionLedgerRepository.findById, CommissionLedgerRepository.findByProviderIdAndStatusIn, CommissionLedgerRepository.save, NotificationRepository.save, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `settlement.error.amount_mismatch, settlement.error.amount_required, settlement.error.not_outstanding`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `A payment reference (1-100 characters) is required; settlement.error.amount_mismatch; settlement.error.amount_required; settlement.error.not_outstanding`.

### PATCH `/admin/providers/{providerId}/settlement-pause` — setSettlementPause (line 338)

- Purpose: setSettlementPause.
- URL access: Authenticated URL filter. Method/class authorization: `Perms.FINANCE`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> setSettlementPause( @PathVariable Long providerId, @RequestParam boolean paused)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, providerRepo.findById, providerRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## StaffController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\StaffController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/providers/{providerId}/staff` — publicStaff (line 35)

- Purpose: publicStaff.
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.StaffMemberDto>>> publicStaff( @PathVariable Long providerId, @RequestParam(required = false) Long serviceId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `StaffMemberRepository.findByProviderIdAndActiveTrueOrderByFullNameAsc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/staff` — add (line 49)

- Purpose: add.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> add( @Valid @RequestBody StaffMemberRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId, staffRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ServiceRepository.findByIdInAndProviderId, StaffMemberRepository.save, UserRepository.findByLogin`.
- Reachable business error keys: `staff.error.unknown_service`.
- Success: 201; return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PUT `/provider/staff/{id}` — update (line 72)

- Purpose: update.
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: `"hasRole('PROVIDER')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.StaffMemberDto>> update( @PathVariable Long id, @Valid @RequestBody StaffMemberRequest request, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.findByUserId, staffRepo.findByIdAndProviderId, staffRepo.save`.
- Reachable database/integration operations: `ProviderProfileRepository.findByUserId, ServiceRepository.findByIdInAndProviderId, StaffMemberRepository.findByIdAndProviderId, StaffMemberRepository.save, UserRepository.findByLogin`.
- Reachable business error keys: `staff.error.unknown_service`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## SupportController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\SupportController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/support/contact` — contact (line 31)

- Purpose: Get WhatsApp support contact info (public).
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> contact()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `supportRepo.findFirstByWhatsappEnabledTrue`.
- Reachable database/integration operations: `SupportSettingsRepository.findFirstByWhatsappEnabledTrue`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/support/admin/settings` — adminGet (line 57)

- Purpose: Get the current support settings (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> adminGet()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: local controller logic / DTO or response construction.
- Reachable database/integration operations: `SupportSettingsRepository.findFirstByOrderByIdAsc, SupportSettingsRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/support/admin/settings` — adminUpdate (line 66)

- Purpose: Update support settings — numbers, hours, escalation email (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.SupportContactDto>> adminUpdate( @Valid @RequestBody SupportSettingsRequest request)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, supportRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, SupportSettingsRepository.findFirstByOrderByIdAsc, SupportSettingsRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## TermsController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\TermsController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/terms/latest` — getLatest (line 42)

- Purpose: Get the latest active terms for a given type (public).
- URL access: Public URL filter; listing/participant checks may narrow data. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> getLatest( @RequestParam(defaultValue = "CUSTOMER_TERMS") String type)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `termsRepo.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc`.
- Reachable database/integration operations: `TermsPolicyRepository.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/terms/accept` — accept (line 51)

- Purpose: Accept the live terms version — stores version + timestamp on the user. .
- URL access: Authenticated URL filter. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> accept( @RequestParam String version, @RequestParam(required = false) String type, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `termsAcceptance.accept, TermsAcceptanceService.mainDocumentOf, termsRepo.findByTypeAndVersion, userRepo.save`.
- Reachable database/integration operations: `TermsAcceptanceRepository.findByUserIdAndType, TermsAcceptanceRepository.save, TermsPolicyRepository.findByTypeAndVersion, UserRepository.findByLogin, UserRepository.save`.
- Reachable business error keys: `terms.error.version_superseded`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `terms.error.version_superseded`.

### GET `/terms` — listAll (line 84)

- Purpose: List all versions of one document type, newest first (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<List<ApiResponse.TermsPolicyDto>>> listAll( @RequestParam(defaultValue = "CUSTOMER_TERMS") String type)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `termsRepo.findByTypeOrderByCreatedAtDescIdDesc`.
- Reachable database/integration operations: `TermsPolicyRepository.findByTypeOrderByCreatedAtDescIdDesc`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/terms` — create (line 93)

- Purpose: Publish a new terms version — becomes Live, older ones of the same type deactivated (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.TermsPolicyDto>> create( @RequestBody(required = false) FreeTextBody body, @RequestParam(required = false) String version, @RequestParam(required = false) String type, @RequestParam(required = false) String contentEn, @RequestParam(required = false) String contentAr, @RequestParam(required = false) String pdfUrl, @RequestParam(required = false) String changeNote)`.
- Validation helpers: `FreeTextBody.bounded, FreeTextBody.pick, FreeTextBody.require`.
- Operations: `auditService.record, termsRepo.existsByTypeAndVersion, termsRepo.findByTypeAndActiveTrue, termsRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, TermsPolicyRepository.existsByTypeAndVersion, TermsPolicyRepository.findByTypeAndActiveTrue, TermsPolicyRepository.save, UserRepository.findByLogin`.
- Success: 201; return shape shown in signature. Controller-specific error messages: `English content is required; PDF link must be an https:// URL or a path on this server; Version already exists: ; Version must be 1–32 characters`.

### PATCH `/terms/{id}/deactivate` — deactivate (line 143)

- Purpose: Deactivate a terms version (ADMIN · Super admin).
- URL access: Authenticated URL filter. Method/class authorization: `com.aiwa.security.Perms.SUPER_ADMIN`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> deactivate(@PathVariable Long id)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, termsRepo.findById, termsRepo.save`.
- Reachable database/integration operations: `AuditLogRepository.save, TermsPolicyRepository.findById, TermsPolicyRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

## VerificationController.java

Source: `D:\AIWA PROJECT\AIWA\aiwa-backend\src\main\java\com\aiwa\controller\VerificationController.java`. Class authorization: none; URL filter and service checks apply.

### GET `/admin/verification/counts` — counts (line 43)

- Purpose: Provider counts by verification status (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `"hasRole('ADMIN')"`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<ApiResponse.VerificationCountsDto>> counts()`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `providerRepo.countByVerificationStatus`.
- Reachable database/integration operations: `ProviderProfileRepository.countByVerificationStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/provider/verification/documents` — submitDocuments (line 57)

- Purpose: Submit national ID + selfie for verification (PROVIDER role).
- URL access: PROVIDER or ADMIN URL filter; profile ownership still required. Method/class authorization: none additional.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> submitDocuments( @RequestParam("nationalIdFront") MultipartFile nationalIdFront, @RequestParam("nationalIdBack") MultipartFile nationalIdBack, @RequestParam("selfie") MultipartFile selfie, @AuthenticationPrincipal UserDetails userDetails)`.
- Validation helpers: `verificationService.requireCanSubmit`.
- Operations: `fileStorageService.storePrivate, limiter.check, verificationService.requireCanSubmit, verificationService.submitDocuments`.
- Reachable database/integration operations: `MeterRegistry.counter, ProviderProfileRepository.findByUserId, ProviderProfileRepository.save, StringRedisTemplate.execute, UserRepository.findByLogin`.
- Reachable business error keys: `upload.error.empty, upload.error.invalid_type, upload.error.storage_failed, upload.error.too_large, verification.error.already_verified, verification.error.suspended`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/verification/pending` — pending (line 93)

- Purpose: List providers pending verification (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderVerificationDto>>> pending( @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `verificationService.searchByVerificationStatus`.
- Reachable database/integration operations: `ProviderProfileRepository.searchByVerificationStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/verification` — byStatus (line 104)

- Purpose: List providers by verification status (ADMIN).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Page<ApiResponse.ProviderVerificationDto>>> byStatus( @RequestParam VerificationStatus status, @RequestParam(required = false) String query, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size)`.
- Validation helpers: `Pages.admin`.
- Operations: `verificationService.searchByVerificationStatus`.
- Reachable database/integration operations: `ProviderProfileRepository.searchByVerificationStatus`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/verification/{providerId}/approve` — approve (line 116)

- Purpose: Approve a provider (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> approve(@PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, verificationService.approve`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save, ProviderWaitlistRepository.findOpenFor, ProviderWaitlistRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `verification.error.documents_missing`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/verification/{providerId}/reject` — reject (line 125)

- Purpose: Reject a provider with reason (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> reject( @PathVariable Long providerId, @RequestParam(required = false) String reason, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.bounded, FreeTextBody.require`.
- Operations: `auditService.record, verificationService.reject`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `verification.error.reason_required`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/verification/{providerId}/request-info` — requestInfo (line 138)

- Purpose: Request more information from a provider (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> requestInfo( @PathVariable Long providerId, @RequestParam(required = false) String message, @RequestBody(required = false) FreeTextBody body)`.
- Validation helpers: `FreeTextBody.bounded, FreeTextBody.require`.
- Operations: `auditService.record, verificationService.requestMoreInfo`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `verification.error.info_message_required`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### PATCH `/admin/verification/{providerId}/note` — saveNote (line 150)

- Purpose: Save the admin-only internal note on a verification case (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> saveNote( @PathVariable Long providerId, @RequestBody java.util.Map<String, String> body)`.
- Validation helpers: `FreeTextBody.bounded`.
- Operations: `verificationService.saveNote`.
- Reachable database/integration operations: `ProviderProfileRepository.findById, ProviderProfileRepository.save`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/verification/{providerId}/suspend` — suspend (line 160)

- Purpose: Suspend a provider (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> suspend(@PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, verificationService.suspend`.
- Reachable database/integration operations: `AuditLogRepository.save, BookingRepository.findByProviderIdAndStatusIn, BookingRepository.save, NotificationRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### POST `/admin/verification/{providerId}/reactivate` — reactivate (line 170)

- Purpose: Reactivate a suspended provider (ADMIN · Support).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT`.
- Input and return signature: `public ResponseEntity<ApiResponse.Success<Void>> reactivate(@PathVariable Long providerId)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, verificationService.reactivate`.
- Reachable database/integration operations: `AuditLogRepository.save, NotificationRepository.save, ProviderProfileRepository.findById, ProviderProfileRepository.save, PushDeviceRepository.findByUserId, UserRepository.findById`.
- Reachable business error keys: `verification.error.not_suspended`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/verification/document` — getDocument (line 183)

- Purpose: Download a private verification document by its stored path (ADMIN only). .
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT) // M-3: identity documents are for verification (Support), not every admin @Operation(summary = "Download a private verification document by its stored path (ADMIN only). " + "Only paths recorded on a provider profile are served; prefer /admin/verification/{providerId}/documents/{kind}."`.
- Input and return signature: `public ResponseEntity<org.springframework.core.io.Resource> getDocument( @RequestParam String filePath)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, providerRepo.existsByNationalIdFrontPathOrNationalIdBackPathOrSelfiePath`.
- Reachable database/integration operations: `AuditLogRepository.save, ProviderProfileRepository.existsByNationalIdFrontPathOrNationalIdBackPathOrSelfiePath`.
- Reachable business error keys: `upload.error.storage_failed`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: common errors and delegated service errors.

### GET `/admin/verification/{providerId}/documents/{kind}` — getDocumentByKind (line 199)

- Purpose: Stream one verification document of a provider — kind: id-front | id-back | selfie (ADMIN only).
- URL access: Authenticated URL filter. Method/class authorization: `Perms.SUPPORT) // M-3 @Operation(summary = "Stream one verification document of a provider — kind: id-front | id-back | selfie (ADMIN only)"`.
- Input and return signature: `public ResponseEntity<org.springframework.core.io.Resource> getDocumentByKind( @PathVariable Long providerId, @PathVariable String kind)`.
- Validation helpers: framework binding; annotated `@Valid` body constraints when present; service validation.
- Operations: `auditService.record, providerRepo.findById`.
- Reachable database/integration operations: `AuditLogRepository.save, ProviderProfileRepository.findById`.
- Reachable business error keys: `upload.error.storage_failed`.
- Success: 200 (other explicit branches may differ); return shape shown in signature. Controller-specific error messages: `Unknown document kind: `.

## Body-validation appendix

These are the current request DTO definitions. Only a mapped method using `@Valid` invokes Bean Validation automatically. A raw `Map` or `FreeTextBody` relies on the explicit controller/service bounds listed above.

### AdminUserRequest.java

```java
public class AdminUserRequest {
    @Data
    public static class CreateAdmin {
        @NotBlank(message = "Full name is required")
        @Size(max = 255, message = "{validation.text.too_long}")
        private String fullName;
        @Size(max = 255, message = "{validation.text.too_long}")
        private String email;
        @Size(max = 32, message = "{validation.text.too_long}")
        private String phone;
        @NotBlank(message = "Password is required")
        @Size(min = 12, max = 72, message = "Admin password must be 12 to 72 characters")
        private String password;
        @NotEmpty(message = "Select at least one permission")
        private List<String> permissions;
    }
    @Data
    public static class EditUser {
        @Size(min = 2, max = 255, message = "Name must be 2 to 255 characters")
        private String fullName;
        @Size(max = 255, message = "{validation.text.too_long}")
        private String email;
        @Size(max = 32, message = "{validation.text.too_long}")
        private String phone;
    }
}
```

### AmendDestinationRequest.java

```java
@Data
public class AmendDestinationRequest {
    @NotNull(message = "A saved address is required")
    private Long savedAddressId;
}
```

### AuthRequest.java

```java
public class AuthRequest {
    @Data
    public static class Register {
        @NotBlank(message = "Full name is required")
        @Size(max = 120, message = "Full name must be at most 120 characters")
        private String fullName;
        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;
        @NotBlank(message = "Password is required")
        @Size(min = 6, max = 72, message = "Password must be 6–72 characters")
        private String password;
        @NotNull(message = "Role is required")
        private UserRole role;
        private Gender gender;
        private Language preferredLanguage = Language.EN;
        @Size(max = 100)
        private String verificationReceipt;
    }
    @Data
    public static class Login {
        @NotBlank(message = "Email or phone is required")
        @Size(max = 255)
        private String identifier;
        @NotBlank(message = "Password is required")
        @Size(max = 128)
        private String password;
    }
    @Data
    public static class RefreshToken {
        @NotBlank
        private String refreshToken;
    }
    @Data
    public static class Logout {
        private String refreshToken;
    }
    @Data
    public static class UpdateLanguage {
        @NotNull(message = "Language is required")
        private Language preferredLanguage;
    }
    @Data
    public static class ResetPassword {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;
        @Email(message = "Enter a valid email address")
        private String email;
        @NotBlank(message = "OTP code is required")
        private String code;
        @NotBlank(message = "New password is required")
        @Size(min = 6, max = 72, message = "Password must be 6–72 characters")
        private String newPassword;
        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }
    @Data
    public static class ChangePhone {
        @NotBlank(message = "Phone is required")
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;
        @NotBlank(message = "Code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "The code is 6 digits")
        private String code;
        @Size(max = 128)
        private String currentPassword;
    }
    @Data
    public static class CurrentPassword {
        @Size(max = 128)
        private String currentPassword;
    }
    @Data
    public static class VerifyEmail {
        @NotBlank(message = "Code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "The code is 6 digits")
        private String code;
    }
    @Data
    public static class VerifyMfa {
        @NotBlank(message = "MFA token is required")
        private String mfaToken;
        @NotBlank(message = "Code is required")
        private String code;
    }
    @Data
    public static class ConfirmIdentity {
        @NotBlank(message = "Password is required")
        @Size(max = 128)
        private String password;
        @Size(max = 10)
        private String code;
    }
    @Data
    public static class EnableTotp {
        @NotBlank(message = "Code is required")
        private String code;
    }
}
```

### AvailabilityRequest.java

```java
@Data
public class AvailabilityRequest {
    private Long staffMemberId;
    @NotNull
    private DayOfWeek dayOfWeek;
    @NotNull
    private LocalTime startTime;
    @NotNull
    private LocalTime endTime;
    @jakarta.validation.constraints.Min(value = 5, message = "Slots must be at least 5 minutes")
    @jakarta.validation.constraints.Max(value = 240, message = "Slots must be at most 240 minutes")
    private Integer slotDurationMinutes = 30;
    private boolean available = true;
}
```

### BookingRequest.java

```java
@Data
public class BookingRequest {
    @NotNull(message = "Provider ID is required")
    private Long providerId;
    @NotNull(message = "Service ID is required")
    private Long serviceId;
    private Long staffMemberId;
    private Long savedAddressId;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate bookingDate;
    private LocalTime startTime;
    @NotNull(message = "Booking type is required")
    private BookingType bookingType = BookingType.SCHEDULED;
    private String paymentMethod = "CASH";
    private Boolean homeService = false;
    @jakarta.validation.constraints.Size(max = 255, message = "Notes must be at most 255 characters")
    private String notes;
}
```

### ChatMessageRequest.java

```java
@Data
public class ChatMessageRequest {
    @NotBlank
    @Size(max = 2000)
    private String message;
}
```

### FreeTextBody.java

```java
public class FreeTextBody extends HashMap<String, String> {
    public static String pick(FreeTextBody body, String key, String param) {
        String value = body == null ? null : body.get(key);
        return value != null ? value : param;
    }
    public static String bounded(String value, int max) {
        if (value != null && value.length() > max) throw new BusinessException("error.text_too_long");
        return value;
    }
    public static String require(FreeTextBody body, String key, String param) {
        String value = pick(body, key, param);
        if (value == null) throw new BusinessException("error.field_required");
        return value;
    }
}
```

### ModerationRequest.java

```java
@Data
public class ModerationRequest {
    @NotNull
    private ModerationTargetType targetType;
    @NotNull
    private Long targetId;
    @Size(max = 1000)
    private String reason;
    @Size(max = 1000)
    private String adminNotes;
}
```

### OtpRequest.java

```java
public class OtpRequest {
    @Data
    public static class SendOtp {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;
        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;
        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }
    @Data
    public static class VerifyOtp {
        @Pattern(regexp = "^\\+?[0-9]{8,15}$", message = "Enter a valid phone number")
        private String phone;
        @Email(message = "Enter a valid email address")
        @Size(max = 255)
        private String email;
        @NotBlank(message = "Code is required")
        @Pattern(regexp = "^[0-9]{6}$", message = "The code is 6 digits")
        private String code;
        @AssertTrue(message = "Provide either a phone number or an email address")
        public boolean isSingleDestination() {
            return (phone != null && !phone.isBlank()) ^ (email != null && !email.isBlank());
        }
    }
}
```

### ProviderProfileRequest.java

```java
@Data
public class ProviderProfileRequest {
    @NotBlank(message = "Business name is required")
    @Size(max = 120, message = "Business name must be at most 120 characters")
    private String businessName;
    @Size(max = 255, message = "Bio must be at most 255 characters")
    private String bio;
    @Size(max = 255, message = "Address must be at most 255 characters")
    private String address;
    @DecimalMin(value = "-90.0", message = "Latitude must be between -90 and 90")
    @DecimalMax(value = "90.0", message = "Latitude must be between -90 and 90")
    private Double latitude;
    @DecimalMin(value = "-180.0", message = "Longitude must be between -180 and 180")
    @DecimalMax(value = "180.0", message = "Longitude must be between -180 and 180")
    private Double longitude;
    private ProviderType providerType;
    private ServiceCategory primaryCategory;
    @Min(value = 0, message = "Travel buffer cannot be negative")
    @Max(value = 240, message = "Travel buffer must be at most 240 minutes")
    private Integer travelBufferMinutes;
    @DecimalMin(value = "0.5", message = "Service radius must be at least 0.5 km")
    @DecimalMax(value = "200.0", message = "Service radius must be at most 200 km")
    private Double serviceRadiusKm;
}
```

### RescheduleRequest.java

```java
@Data
public class RescheduleRequest {
    @NotNull(message = "New booking date is required")
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate bookingDate;
    @NotNull(message = "New start time is required")
    private LocalTime startTime;
    @jakarta.validation.constraints.Size(max = 255, message = "{validation.text.too_long}")
    private String reason;
}
```

### ReviewRequest.java

```java
@Data
public class ReviewRequest {
    @NotNull(message = "Booking ID is required")
    private Long bookingId;
    @NotNull(message = "Rating is required")
    @Min(1) @Max(5)
    private Integer rating;
    @Size(max = 1000)
    private String comment;
    private List<String> quickTags;
    private ReviewDirection direction = ReviewDirection.CUSTOMER_TO_PROVIDER;
}
```

### SafetyEventRequest.java

```java
@Data
public class SafetyEventRequest {
    @NotNull
    private SafetyEventType type;
    @jakarta.validation.constraints.DecimalMin("-90") @jakarta.validation.constraints.DecimalMax("90")
    private Double latitude;
    @jakarta.validation.constraints.DecimalMin("-180") @jakarta.validation.constraints.DecimalMax("180")
    private Double longitude;
    private java.time.Instant locationTime;
    @jakarta.validation.constraints.DecimalMin("0") @jakarta.validation.constraints.DecimalMax("100000")
    private Double locationAccuracy;
    @Size(max = 1000)
    private String notes;
}
```

### SavedAddressRequest.java

```java
@Data
public class SavedAddressRequest {
    @NotBlank(message = "Label is required")
    @Size(max = 60, message = "Label must be at most 60 characters")
    private String label;
    @NotBlank(message = "Address is required")
    @Size(max = 255, message = "Address must be at most 255 characters")
    private String addressLine;
    @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0")
    private Double latitude;
    @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0")
    private Double longitude;
    private Boolean defaultAddress;
}
```

### ServiceRequest.java

```java
@Data
public class ServiceRequest {
    @NotBlank(message = "Service name is required")
    @Size(max = 255, message = "{validation.text.too_long}")
    private String name;
    @Size(max = 255, message = "{validation.text.too_long}")
    private String description;
    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.0", inclusive = false, message = "Price must be positive")
    @DecimalMax(value = "1000000", message = "{validation.price.max}")
    @Digits(integer = 8, fraction = 2, message = "{validation.price.max}")
    private BigDecimal price;
    @NotNull(message = "Duration is required")
    @Min(value = 5, message = "Duration must be at least 5 minutes")
    @Max(value = 480, message = "{validation.duration.max}")
    private Integer durationMinutes;
    private ServiceCategory category;
    private PricingType pricingType = PricingType.FIXED;
    private boolean transportIncluded = false;
}
```

### StaffMemberRequest.java

```java
@Data
public class StaffMemberRequest {
    @NotBlank
    @Size(max = 120)
    private String fullName;
    @Size(max = 80)
    private String title;
    @Pattern(regexp = "^[+]?[0-9][0-9 -]{6,19}$", message = "Enter a valid phone number")
    private String phone;
    @Size(max = 255)
    private String skills;
    private Boolean active;
    private List<Long> serviceIds;
}
```

### SupportSettingsRequest.java

```java
@Data
public class SupportSettingsRequest {
    private List<Line> numbers;
    private String availabilityHoursEn;
    private String availabilityHoursAr;
    @Email(message = "Escalation email must be a valid email address")
    private String supportEmail;
    private Boolean whatsappEnabled;
    @Data
    public static class Line {
        private String label;
        private String number;
        private String displayNumber;
        private boolean primary;
        private boolean enabled = true;
    }
}
```

### TrustedContactRequest.java

```java
@Data
public class TrustedContactRequest {
    @NotBlank(message = "Name is required")
    @Size(max = 120, message = "Name must be at most 120 characters")
    private String name;
    @NotBlank(message = "Phone is required")
    @Pattern(regexp = "^\\+?[0-9][0-9 \\-]{6,19}$", message = "Enter a valid phone number")
    private String phone;
    @Size(max = 60, message = "Relationship must be at most 60 characters")
    private String relationship;
}
```

### UpdateNotificationPreferencesRequest.java

```java
@Data
public class UpdateNotificationPreferencesRequest {
    private Boolean notifyPush;
    private Boolean notifyEmail;
    private Boolean notifySms;
    private Boolean notifyWhatsapp;
    private Boolean muteAll;
    @DateTimeFormat(pattern = "HH:mm")
    private LocalTime quietHoursStart;
    @DateTimeFormat(pattern = "HH:mm")
    private LocalTime quietHoursEnd;
    private Boolean clearQuietHours;
}
```

### UpdatePreferencesRequest.java

```java
@Data
public class UpdatePreferencesRequest {
    @Min(value = 1, message = "Minimum radius must be at least 1 km")
    private Double searchRadiusMinKm;
    @Max(value = 100, message = "Maximum radius cannot exceed 100 km")
    private Double searchRadiusMaxKm;
    @Size(max = 120, message = "Area name must be at most 120 characters")
    private String searchAreaLabel;
    @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0")
    private Double searchAreaLatitude;
    @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0")
    private Double searchAreaLongitude;
    private Boolean clearSearchArea;
}
```

### UpdateProfileRequest.java

```java
@Data
public class UpdateProfileRequest {
    @NotBlank(message = "Full name is required")
    private String fullName;
    private String email;
    @jakarta.validation.constraints.Size(max = 128)
    private String currentPassword;
    private String profileImageUrl;
}
```

### UpdatePushTokenRequest.java

```java
@Data
public class UpdatePushTokenRequest {
    @NotBlank(message = "Device token is required")
    private String token;
    @NotNull(message = "Device platform is required")
    private DevicePlatform platform;
}
```

Inventory count: 183 mapped handler methods across 29 controllers (multi-verb handlers listed once). Actuator and SpringDoc framework endpoints are not application controller mappings.
