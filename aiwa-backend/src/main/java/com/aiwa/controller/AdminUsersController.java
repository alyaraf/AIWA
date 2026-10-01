package com.aiwa.controller;

import com.aiwa.dto.request.AdminUserRequest;
import com.aiwa.dto.response.ApiResponse;
import com.aiwa.entity.User;
import com.aiwa.enums.Language;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.exception.ResourceNotFoundException;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/admin/users")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
@Tag(name = "Admin â€” Users", description = "Admin user management endpoints")
public class AdminUsersController {

    private final UserRepository userRepo;
    private final ProviderProfileRepository providerRepo;
    private final BookingRepository bookingRepo;
    private final com.aiwa.repository.ReviewRepository reviewRepo;
    private final com.aiwa.repository.ComplaintRepository complaintRepo;
    private final PasswordEncoder passwordEncoder;
    private final com.aiwa.service.impl.NotificationServiceImpl notificationService;
    private final com.aiwa.service.impl.AuditService auditService;
    private final com.aiwa.service.impl.AccountDeletionService accountDeletion;

    @GetMapping
    @Operation(summary = "List all users â€” filter by role, search by name/phone/email")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<Page<ApiResponse.UserDto>>> listUsers(
            @RequestParam(required = false) String role,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0")  int page,
            @RequestParam(defaultValue = "20") int size) {

        Pageable pageable = com.aiwa.util.Pages.admin(page, size);
        UserRole r = null;
        if (role != null && !role.isBlank()) {
            try {
                r = UserRole.valueOf(role.toUpperCase());
            } catch (IllegalArgumentException ex) {
                throw new BusinessException("Invalid role filter: " + role);
            }
        }
        Page<User> users = userRepo.adminSearch(r, likePattern(q), pageable);

        java.util.List<ApiResponse.UserDto> dtos = users.getContent().stream().map(this::toDto).toList();
        return ResponseEntity.ok(ApiResponse.Success.of(
                new org.springframework.data.domain.PageImpl<>(dtos, pageable, users.getTotalElements())));
    }

    @PostMapping("/admins")
    @Operation(summary = "Create another admin user (SUPER_ADMIN)")
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> createAdmin(
            @Valid @RequestBody AdminUserRequest.CreateAdmin request,
            @AuthenticationPrincipal UserDetails userDetails) {
        requireSuperAdmin(resolveUser(userDetails));
        java.util.Set<com.aiwa.enums.AdminPermission> permissions = parsePermissions(request.getPermissions());

        if ((request.getEmail() == null || request.getEmail().isBlank())
                && (request.getPhone() == null || request.getPhone().isBlank())) {
            throw new BusinessException("Email or phone is required");
        }
        if (request.getEmail() != null && !request.getEmail().isBlank()
                && userRepo.existsByEmail(request.getEmail())) {
            throw new BusinessException("Email already in use");
        }
        if (request.getPhone() != null && !request.getPhone().isBlank()
                && userRepo.existsByPhone(request.getPhone())) {
            throw new BusinessException("Phone number already in use");
        }

        User admin = User.builder()
                .fullName(request.getFullName())
                .email(blankToNull(request.getEmail()))
                .phone(blankToNull(request.getPhone()))
                .password(passwordEncoder.encode(request.getPassword()))
                .role(UserRole.ADMIN)
                .preferredLanguage(Language.EN)
                .active(true)
                .termsAccepted(true)
                .adminPermissions(permissions)
                .build();

        User saved = userRepo.save(admin);
        notificationService.send(
                saved.getId(),
                com.aiwa.enums.NotificationType.ADMIN_ACCOUNT_CREATED,
                "Your admin account was created",
                "تم إنشاء حساب المشرف الخاص بك",
                "An administrator account has been created for you on AIWA. You can now sign in.",
                "تم إنشاء حساب مشرف لك على AIWA. يمكنك الآن تسجيل الدخول.",
                null, null
        );
        auditService.record("ADMIN_CREATED", saved.getEmail() != null ? saved.getEmail() : saved.getFullName());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.Success.of("Admin user created", toDto(saved)));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get user detail by ID")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> getUser(@PathVariable Long id) {
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        return ResponseEntity.ok(ApiResponse.Success.of(toDto(u)));
    }

    @GetMapping("/{id}/activity")
    @Operation(summary = "Recent bookings, reviews and complaints for one account (ADMIN)")
    @org.springframework.transaction.annotation.Transactional(readOnly = true)
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserActivityDto>> activity(@PathVariable Long id) {
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        Pageable top = PageRequest.of(0, 20);

        java.util.List<ApiResponse.ActivityBookingDto> bookings;
        Long providerProfileId = u.getProviderProfile() != null ? u.getProviderProfile().getId() : null;
        if (u.getRole() == UserRole.PROVIDER && providerProfileId != null) {
            bookings = bookingRepo.findByProviderIdOrderByCreatedAtDesc(providerProfileId, top)
                    .stream().map(b -> toActivityBooking(b, false)).toList();
        } else {
            bookings = bookingRepo.findByCustomerIdOrderByCreatedAtDesc(u.getId(), top)
                    .stream().map(b -> toActivityBooking(b, true)).toList();
        }

        java.util.List<ApiResponse.ActivityReviewDto> reviews = reviewRepo
                .findByUserIdOrderByCreatedAtDesc(u.getId(), top)
                .stream().map(r -> ApiResponse.ActivityReviewDto.builder()
                        .id(r.getId())
                        .providerName(r.getProvider() != null ? r.getProvider().getBusinessName() : "Provider")
                        .rating(r.getRating())
                        .comment(r.getComment())
                        .hidden(r.isHidden())
                        .createdAt(r.getCreatedAt())
                        .build())
                .toList();

        java.util.List<ApiResponse.ActivityComplaintDto> complaints = complaintRepo
                .findByReporterIdOrderByCreatedAtDesc(u.getId(), top)
                .stream().map(c -> ApiResponse.ActivityComplaintDto.builder()
                        .id(c.getId())
                        .subject(c.getDescription() != null && !c.getDescription().isBlank()
                                ? c.getDescription() : c.getCategory())
                        .status(c.getStatus())
                        .flagged(c.isFlagged())
                        .createdAt(c.getCreatedAt())
                        .build())
                .toList();

        return ResponseEntity.ok(ApiResponse.Success.of(ApiResponse.UserActivityDto.builder()
                .bookings(bookings).reviews(reviews).complaints(complaints).build()));
    }

    private ApiResponse.ActivityBookingDto toActivityBooking(com.aiwa.entity.Booking b, boolean viewerIsCustomer) {
        String counterparty = viewerIsCustomer
                ? (b.getProvider() != null ? b.getProvider().getBusinessName() : "Provider")
                : (b.getCustomer() != null ? b.getCustomer().getFullName() : "Customer");
        return ApiResponse.ActivityBookingDto.builder()
                .id(b.getId())
                .reference("BK-" + b.getId())
                .counterparty(counterparty)
                .service(b.getService() != null ? b.getService().getName() : "Service")
                .status(b.getStatus())
                .paymentStatus(b.getPaymentStatus())
                .amount(b.getTotalPrice())
                .date(b.getBookingDate())
                .createdAt(b.getCreatedAt())
                .build();
    }

    @PatchMapping("/{id}/deactivate")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "Deactivate (suspend) a user account (ADMIN · Support; another admin needs SUPER_ADMIN)")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<Void>> deactivate(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        // Serialises every change that could remove the last active super admin
        // (DR-007): the count used to be read and then written separately, so two
        // parallel deactivations could each see "2 left" and leave none.
        userRepo.lockActiveSuperAdmins();
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        User currentAdmin = resolveUser(userDetails);

        if (currentAdmin.getId().equals(u.getId())) {
            throw new BusinessException("You cannot deactivate your own admin account");
        }
        // DR-007: a SUPPORT-only admin could suspend a super admin. Changing any
        // admin account is a SUPER_ADMIN action, like edit, permissions and reset.
        if (UserRole.ADMIN.equals(u.getRole())) {
            requireSuperAdmin(currentAdmin);
        }
        if (UserRole.ADMIN.equals(u.getRole())
                && u.isActive()
                && userRepo.countByRoleAndActive(UserRole.ADMIN, true) <= 1) {
            throw new BusinessException("Cannot deactivate the last active admin user");
        }
        if (UserRole.ADMIN.equals(u.getRole())
                && u.isActive()
                && u.hasPermission(com.aiwa.enums.AdminPermission.SUPER_ADMIN)
                && userRepo.countActiveSuperAdmins() <= 1) {
            throw new BusinessException("Can't deactivate " + u.getFullName()
                    + " — they're the last active super admin");
        }

        u.setActive(false);
        // End every session now, not when the access token expires.
        u.setTokensValidAfter(java.time.Instant.now());
        userRepo.save(u);
        auditService.record("USER_DEACTIVATED", u.getFullName());
        return ResponseEntity.ok(ApiResponse.Success.of("User deactivated", null));
    }

    @PatchMapping("/{id}/reactivate")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "Reactivate a deactivated user account (ADMIN · Support; another admin needs SUPER_ADMIN)")
    public ResponseEntity<ApiResponse.Success<Void>> reactivate(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        User u = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        if (UserRole.ADMIN.equals(u.getRole())) {
            requireSuperAdmin(resolveUser(userDetails));
        }
        u.setActive(true);
        userRepo.save(u);
        auditService.record("USER_REACTIVATED", u.getFullName());
        return ResponseEntity.ok(ApiResponse.Success.of("User reactivated", null));
    }


    @DeleteMapping("/{id}")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Delete a user account (ADMIN · Super admin)")
    public ResponseEntity<ApiResponse.Success<Void>> deleteUser(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        User user = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        User currentAdmin = resolveUser(userDetails);

        if (currentAdmin.getId().equals(user.getId())) {
            throw new BusinessException("You cannot delete your own admin account");
        }
        if (UserRole.ADMIN.equals(user.getRole()) && userRepo.countByRole(UserRole.ADMIN) <= 1) {
            throw new BusinessException("Cannot delete the last admin user");
        }

        String label = user.getFullName();
        if (UserRole.ADMIN.equals(user.getRole())) {
            try {
                userRepo.delete(user);
            } catch (DataIntegrityViolationException ex) {
                throw new BusinessException("User has related records. Deactivate the account instead.");
            }
        } else {
            // A deletion request to support (OPS-4): the same erasure as in-app
            // deletion. A hard delete failed for anyone who had ever booked.
            accountDeletion.delete(user);
        }
        auditService.record("USER_DELETED", label + " (#" + id + ")");
        return ResponseEntity.ok(ApiResponse.Success.of("User deleted", null));
    }

    @PatchMapping("/{id}/permissions")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPER_ADMIN)
    @Operation(summary = "Update an admin's permissions (SUPER_ADMIN)")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> updatePermissions(
            @PathVariable Long id,
            @RequestParam java.util.List<String> permissions,
            @AuthenticationPrincipal UserDetails userDetails) {
        userRepo.lockActiveSuperAdmins(); // DR-007, see deactivate()
        requireSuperAdmin(resolveUser(userDetails));
        User target = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        if (!UserRole.ADMIN.equals(target.getRole())) {
            throw new BusinessException("Permissions apply to admin users only");
        }
        java.util.Set<com.aiwa.enums.AdminPermission> next = parsePermissions(permissions);
        if (target.hasPermission(com.aiwa.enums.AdminPermission.SUPER_ADMIN)
                && !next.contains(com.aiwa.enums.AdminPermission.SUPER_ADMIN)
                && userRepo.countActiveSuperAdmins() <= 1) {
            throw new BusinessException("Can't remove super admin from " + target.getFullName()
                    + " — they're the last active super admin");
        }
        target.setAdminPermissions(next);
        userRepo.save(target);
        auditService.record("ADMIN_PERMISSIONS_UPDATED", target.getFullName() + " → " + next);
        return ResponseEntity.ok(ApiResponse.Success.of("Permissions updated", toDto(target)));
    }

    @PatchMapping("/{id}")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "Edit a user's contact details — name / email / phone (ADMIN · Support)")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<ApiResponse.UserDto>> editUser(
            @PathVariable Long id,
            @jakarta.validation.Valid @RequestBody AdminUserRequest.EditUser request,
            @AuthenticationPrincipal UserDetails userDetails) {
        User target = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        // Editing another admin's details is a super-admin action.
        if (UserRole.ADMIN.equals(target.getRole())) {
            requireSuperAdmin(resolveUser(userDetails));
        }

        java.util.List<String> changed = new java.util.ArrayList<>();
        String name = request.getFullName() == null ? null : request.getFullName().trim();
        String email = blankToNull(request.getEmail() == null ? null : request.getEmail().trim().toLowerCase());
        String phone = blankToNull(request.getPhone() == null ? null : request.getPhone().trim());

        if (name != null && !name.equals(target.getFullName())) {
            target.setFullName(name);
            changed.add("name");
        }
        if (email != null && !email.equalsIgnoreCase(target.getEmail() == null ? "" : target.getEmail())) {
            if (userRepo.existsByEmail(email)) throw new BusinessException("That email is already in use");
            target.setEmail(email);
            changed.add("email");
        }
        if (phone != null && !phone.equals(target.getPhone())) {
            if (userRepo.existsByPhone(phone)) throw new BusinessException("That phone number is already in use");
            target.setPhone(phone);
            changed.add("phone");
        }
        if (target.getEmail() == null && target.getPhone() == null) {
            throw new BusinessException("A user must keep at least an email or a phone number");
        }
        if (changed.isEmpty()) {
            return ResponseEntity.ok(ApiResponse.Success.of("No changes", toDto(target)));
        }
        userRepo.save(target);
        auditService.record("USER_DETAILS_UPDATED", target.getFullName() + " (" + String.join(", ", changed) + ")");
        return ResponseEntity.ok(ApiResponse.Success.of("Details updated", toDto(target)));
    }

    @PostMapping("/{id}/reset-password")
    @org.springframework.security.access.prepost.PreAuthorize(com.aiwa.security.Perms.SUPPORT)
    @Operation(summary = "Set a one-time temporary password for a locked-out user (ADMIN · Support)")
    @org.springframework.transaction.annotation.Transactional
    public ResponseEntity<ApiResponse.Success<java.util.Map<String, String>>> resetPassword(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        User target = userRepo.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User", id));
        if (UserRole.ADMIN.equals(target.getRole())) {
            requireSuperAdmin(resolveUser(userDetails));
        }
        String temp = generateTempPassword();
        target.setPassword(passwordEncoder.encode(temp));
        // Sessions opened with the old password (possibly by whoever locked the user out) end now.
        target.setTokensValidAfter(java.time.Instant.now());
        userRepo.save(target);
        auditService.record("PASSWORD_RESET", target.getFullName());
        notificationService.send(target.getId(), com.aiwa.enums.NotificationType.ACCOUNT_WARNING,
                "Your password was reset", "تمت إعادة تعيين كلمة المرور الخاصة بك",
                "An administrator reset your password. Sign in with the temporary password you were given, then change it.",
                "قام أحد المشرفين بإعادة تعيين كلمة مرورك. سجّل الدخول بكلمة المرور المؤقتة ثم قم بتغييرها.",
                null, null);
        return ResponseEntity.ok(ApiResponse.Success.of("Temporary password created",
                java.util.Map.of("temporaryPassword", temp)));
    }

    private static String generateTempPassword() {
        String chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        StringBuilder sb = new StringBuilder("Aiwa-");
        for (int i = 0; i < 8; i++) sb.append(chars.charAt(rnd.nextInt(chars.length())));
        return sb.toString();
    }

    private ApiResponse.UserDto toDto(User u) {
        Long providerProfileId = u.getProviderProfile() != null ? u.getProviderProfile().getId() : null;
        com.aiwa.enums.VerificationStatus providerStatus =
                u.getProviderProfile() != null ? u.getProviderProfile().getVerificationStatus() : null;
        Long bookingCount = null;
        if (u.getRole() == UserRole.CUSTOMER) {
            bookingCount = bookingRepo.countByCustomerId(u.getId());
        } else if (providerProfileId != null) {
            bookingCount = bookingRepo.countByProviderId(providerProfileId);
        }
        return ApiResponse.UserDto.builder()
                .id(u.getId())
                .fullName(u.getFullName())
                .email(u.getEmail())
                .phone(u.getPhone())
                .role(u.getRole())
                .gender(u.getGender())
                .profileImageUrl(u.getProfileImageUrl())
                .preferredLanguage(u.getPreferredLanguage())
                .termsAccepted(u.isTermsAccepted())
                .active(u.isActive())
                .permissions(u.getAdminPermissions() == null ? java.util.List.of()
                        : u.getAdminPermissions().stream().map(Enum::name).sorted().toList())
                .providerProfileId(providerProfileId)
                .providerStatus(providerStatus)
                .bookingCount(bookingCount)
                .createdAt(u.getCreatedAt())
                .build();
    }

    /** SUPER_ADMIN is required for privileged admin ops — but bootstrap the first one. */
    private void requireSuperAdmin(User currentAdmin) {
        if (userRepo.countActiveSuperAdmins() == 0) return; // bootstrap: no super admin exists yet
        if (!currentAdmin.hasPermission(com.aiwa.enums.AdminPermission.SUPER_ADMIN)) {
            throw new BusinessException("This action requires the SUPER_ADMIN permission");
        }
    }

    private java.util.Set<com.aiwa.enums.AdminPermission> parsePermissions(java.util.List<String> raw) {
        if (raw == null || raw.isEmpty()) {
            throw new BusinessException("Select at least one permission");
        }
        java.util.Set<com.aiwa.enums.AdminPermission> set = new java.util.HashSet<>();
        for (String value : raw) {
            try {
                set.add(com.aiwa.enums.AdminPermission.valueOf(value.trim().toUpperCase()));
            } catch (IllegalArgumentException ex) {
                throw new BusinessException("Unknown permission: " + value);
            }
        }
        return set;
    }


    private User resolveUser(UserDetails userDetails) {
        return userRepo.findByLogin(userDetails.getUsername())
                .orElseThrow(() -> new BusinessException("Current admin not found"));
    }
    /** "%term%" in lower case, or "%" for no search; wildcards the admin typed are dropped. */
    static String likePattern(String query) {
        if (query == null) return "%";
        String q = query.strip().toLowerCase().replace("%", "").replace("_", "");
        return q.isEmpty() ? "%" : "%" + q + "%";
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
