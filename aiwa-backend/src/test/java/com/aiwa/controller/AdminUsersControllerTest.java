package com.aiwa.controller;

import com.aiwa.dto.request.AdminUserRequest;
import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.UserRole;
import com.aiwa.exception.BusinessException;
import com.aiwa.repository.BookingRepository;
import com.aiwa.repository.ProviderProfileRepository;
import com.aiwa.repository.UserRepository;
import com.aiwa.service.impl.AuditService;
import com.aiwa.service.impl.NotificationServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

/**
 * Authorization guards for admin-driven account deactivation.
 */
class AdminUsersControllerTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final ProviderProfileRepository providerRepo = mock(ProviderProfileRepository.class);
    private final BookingRepository bookingRepo = mock(BookingRepository.class);
    private final com.aiwa.repository.ReviewRepository reviewRepo = mock(com.aiwa.repository.ReviewRepository.class);
    private final com.aiwa.repository.ComplaintRepository complaintRepo = mock(com.aiwa.repository.ComplaintRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final NotificationServiceImpl notificationService = mock(NotificationServiceImpl.class);
    private final AuditService auditService = mock(AuditService.class);
    private final com.aiwa.service.impl.AccountDeletionService accountDeletion =
            mock(com.aiwa.service.impl.AccountDeletionService.class);

    private final AdminUsersController controller =
            new AdminUsersController(userRepo, providerRepo, bookingRepo, reviewRepo, complaintRepo, encoder, notificationService, auditService, accountDeletion);

    private UserDetails principal(String username) {
        return new org.springframework.security.core.userdetails.User(
                username, "pw", List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private User admin(long id, String email, boolean active) {
        return User.builder().id(id).email(email).role(UserRole.ADMIN).active(active).build();
    }

    @Test
    void deletingACustomerErasesTheirDataInsteadOfAHardDelete() {
        User me = admin(1L, "me@x.com", true);
        User customer = User.builder().id(5L).fullName("Layla").email("l@x.com").role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(me));
        when(userRepo.findById(5L)).thenReturn(Optional.of(customer));

        controller.deleteUser(5L, principal("me@x.com"));

        // OPS-4: a support deletion request works for someone with bookings (the
        // hard delete used to fail on their rows) and erases what the policy promises.
        verify(accountDeletion).delete(customer);
        verify(userRepo, never()).delete(any(User.class));
        verify(auditService).record(eq("USER_DELETED"), contains("#5"));
    }

    @Test
    void adminCannotDeactivateSelf() {
        User self = admin(1L, "me@x.com", true);
        when(userRepo.findById(1L)).thenReturn(Optional.of(self));
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(self));

        assertThatThrownBy(() -> controller.deactivate(1L, principal("me@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("your own");
        verify(userRepo, never()).save(any());
    }

    @Test
    void cannotDeactivateLastActiveAdmin() {
        User me = admin(1L, "me@x.com", true);
        User other = admin(2L, "other@x.com", true);
        when(userRepo.findById(2L)).thenReturn(Optional.of(other));
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(me));
        when(userRepo.countByRoleAndActive(UserRole.ADMIN, true)).thenReturn(1L);

        assertThatThrownBy(() -> controller.deactivate(2L, principal("me@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("last active admin");
        verify(userRepo, never()).save(any());
    }

    @Test
    void canDeactivateCustomer() {
        User me = admin(1L, "me@x.com", true);
        User customer = User.builder().id(3L).email("c@x.com")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(me));

        assertThatCode(() -> controller.deactivate(3L, principal("me@x.com")))
                .doesNotThrowAnyException();
        verify(userRepo).save(argThat(u -> !u.isActive() && u.getId().equals(3L)));
    }

    // ── Admin permissions ───────────────────────────────────────────────────

    private User superAdmin(long id, String email) {
        return User.builder().id(id).email(email).role(UserRole.ADMIN).active(true)
                .adminPermissions(new java.util.HashSet<>(Set.of(AdminPermission.SUPER_ADMIN))).build();
    }

    private AdminUserRequest.CreateAdmin createReq(List<String> perms) {
        AdminUserRequest.CreateAdmin r = new AdminUserRequest.CreateAdmin();
        r.setFullName("New Admin");
        r.setEmail("new@aiwa.com");
        r.setPassword("longenoughpassword");
        r.setPermissions(perms);
        return r;
    }

    @Test
    void nonSuperAdminCannotCreateAdmin() {
        User plain = admin(1L, "support@x.com", true); // no permissions
        when(userRepo.findByLogin("support@x.com")).thenReturn(Optional.of(plain));
        when(userRepo.countActiveSuperAdmins()).thenReturn(2L);

        assertThatThrownBy(() -> controller.createAdmin(createReq(List.of("SUPPORT")), principal("support@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("SUPER_ADMIN");
    }

    @Test
    void superAdminCreatesAdminWithPermissions() {
        User boss = superAdmin(1L, "boss@x.com");
        when(userRepo.findByLogin("boss@x.com")).thenReturn(Optional.of(boss));
        when(userRepo.countActiveSuperAdmins()).thenReturn(1L);
        when(encoder.encode(anyString())).thenReturn("hash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> { User u = inv.getArgument(0); u.setId(9L); return u; });

        var response = controller.createAdmin(createReq(List.of("SUPPORT", "FINANCE")), principal("boss@x.com"));

        assertThat(response.getBody().getData().getPermissions()).containsExactlyInAnyOrder("SUPPORT", "FINANCE");
    }

    @Test
    void bootstrapAllowsFirstAdminWithoutSuperAdmin() {
        User plain = admin(1L, "first@x.com", true);
        when(userRepo.findByLogin("first@x.com")).thenReturn(Optional.of(plain));
        when(userRepo.countActiveSuperAdmins()).thenReturn(0L);
        when(encoder.encode(anyString())).thenReturn("hash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> { User u = inv.getArgument(0); u.setId(2L); return u; });

        assertThatCode(() -> controller.createAdmin(createReq(List.of("SUPER_ADMIN")), principal("first@x.com")))
                .doesNotThrowAnyException();
    }

    @Test
    void cannotDeactivateLastSuperAdmin() {
        User me = superAdmin(1L, "me@x.com");
        User target = superAdmin(2L, "target@x.com");
        when(userRepo.findById(2L)).thenReturn(Optional.of(target));
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(me));
        when(userRepo.countByRoleAndActive(UserRole.ADMIN, true)).thenReturn(3L); // other admins exist
        when(userRepo.countActiveSuperAdmins()).thenReturn(1L);

        assertThatThrownBy(() -> controller.deactivate(2L, principal("me@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("last active super admin");
    }

    // ── Edit details + password reset ───────────────────────────────────────

    private AdminUserRequest.EditUser editReq(String name, String email, String phone) {
        AdminUserRequest.EditUser r = new AdminUserRequest.EditUser();
        r.setFullName(name); r.setEmail(email); r.setPhone(phone);
        return r;
    }

    @Test
    void editUserUpdatesChangedFieldsAndChecksUniqueness() {
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com").phone("+201")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.existsByEmail("new@x.com")).thenReturn(false);
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        var res = controller.editUser(3L, editReq("Layla Hassan", "new@x.com", "+201"), principal("admin@x.com"));

        assertThat(customer.getFullName()).isEqualTo("Layla Hassan");
        assertThat(customer.getEmail()).isEqualTo("new@x.com");
        assertThat(res.getBody().getData().getEmail()).isEqualTo("new@x.com");
        verify(auditService).record(eq("USER_DETAILS_UPDATED"), contains("name, email"));
    }

    @Test
    void editUserRejectsDuplicateEmail() {
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.existsByEmail("taken@x.com")).thenReturn(true);

        assertThatThrownBy(() -> controller.editUser(3L, editReq(null, "taken@x.com", null), principal("admin@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already in use");
        verify(userRepo, never()).save(any());
    }

    @Test
    void editAdminRequiresSuperAdmin() {
        User plain = admin(1L, "support@x.com", true); // no perms
        User targetAdmin = admin(2L, "other@x.com", true);
        when(userRepo.findById(2L)).thenReturn(Optional.of(targetAdmin));
        when(userRepo.findByLogin("support@x.com")).thenReturn(Optional.of(plain));
        when(userRepo.countActiveSuperAdmins()).thenReturn(2L);

        assertThatThrownBy(() -> controller.editUser(2L, editReq("Renamed", null, null), principal("support@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("SUPER_ADMIN");
    }

    @Test
    void resetPasswordReturnsTempAndReencodes() {
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com")
                .role(UserRole.CUSTOMER).active(true).password("oldhash").build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(encoder.encode(anyString())).thenReturn("newhash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        var res = controller.resetPassword(3L, principal("admin@x.com"));

        String temp = res.getBody().getData().get("temporaryPassword");
        assertThat(temp).startsWith("Aiwa-").hasSize(13);
        assertThat(customer.getPassword()).isEqualTo("newhash");
        verify(auditService).record(eq("PASSWORD_RESET"), eq("Layla"));
    }
}
