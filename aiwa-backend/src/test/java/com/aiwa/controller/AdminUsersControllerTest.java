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
            new AdminUsersController(userRepo, providerRepo, bookingRepo, reviewRepo, complaintRepo, encoder, notificationService, auditService, accountDeletion,
                    mock(com.aiwa.service.impl.BookingServiceImpl.class));

    {
        // F-03: changing a sign-in contact is a super-admin action; "admin@x.com" is that admin in these tests.
        when(userRepo.findByLogin("admin@x.com")).thenReturn(Optional.of(User.builder().id(900L).email("admin@x.com")
                .role(UserRole.ADMIN).active(true)
                .adminPermissions(new java.util.HashSet<>(Set.of(AdminPermission.SUPER_ADMIN))).build()));
    }

    @Test
    void aSupportAdminCannotMoveAUsersSignInContact() {
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com").phone("+201000000001")
                .role(UserRole.CUSTOMER).active(true).build();
        User support = User.builder().id(901L).email("sup@x.com").role(UserRole.ADMIN).active(true)
                .adminPermissions(new java.util.HashSet<>(Set.of(AdminPermission.SUPPORT))).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.findByLogin("sup@x.com")).thenReturn(Optional.of(support));
        when(userRepo.countActiveSuperAdmins()).thenReturn(1L);

        assertThatThrownBy(() -> controller.editUser(3L, editReq(null, null, "01099999999"), principal("sup@x.com")))
                .hasMessageContaining("SUPER_ADMIN");
        assertThatThrownBy(() -> controller.editUser(3L, editReq(null, "evil@x.com", null), principal("sup@x.com")))
                .hasMessageContaining("SUPER_ADMIN");
        verify(userRepo, never()).save(any());
    }

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
    void cannotDeleteTheLastActiveSuperAdminAndTheDeleteTakesTheLock() {
        // L-5: delete had no last-super-admin rule and no row lock (deactivate has both, DR-007).
        User me = superAdmin(1L, "me@x.com");
        User target = superAdmin(2L, "target@x.com");
        when(userRepo.findById(2L)).thenReturn(Optional.of(target));
        when(userRepo.findByLogin("me@x.com")).thenReturn(Optional.of(me));
        when(userRepo.countByRole(UserRole.ADMIN)).thenReturn(3L);
        when(userRepo.countActiveSuperAdmins()).thenReturn(1L);

        assertThatThrownBy(() -> controller.deleteUser(2L, principal("me@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("last active super admin");
        verify(userRepo).lockActiveSuperAdmins();
        verify(userRepo, never()).delete(any(User.class));
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
    void resetPasswordSendsTheTempToTheUserNotTheAdmin() {
        // AU-08 / M-3: the admin never sees the password.
        com.aiwa.service.SmsService sms = mock(com.aiwa.service.SmsService.class);
        org.springframework.test.util.ReflectionTestUtils.setField(controller, "smsService", sms);
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com")
                        .phone("+201000000009").role(UserRole.CUSTOMER).active(true).password("oldhash").build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(encoder.encode(anyString())).thenReturn("newhash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        var res = controller.resetPassword(3L, principal("admin@x.com"));

        assertThat(res.getBody().getData()).doesNotContainKey("temporaryPassword")
                .containsEntry("delivery", "SMS").containsEntry("sentTo", "***0009");
        org.mockito.ArgumentCaptor<String> text = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(sms).send(eq("+201000000009"), text.capture());
        assertThat(text.getValue()).containsPattern("Aiwa-[A-Za-z0-9]{8}");
        assertThat(customer.getPassword()).isEqualTo("newhash");
        verify(auditService).record(eq("PASSWORD_RESET"), eq("Layla (sent by SMS)"));
    }

    @Test
    void resetPasswordFailsWithoutAChannelAndWhenDeliveryFails() {
        com.aiwa.service.SmsService sms = mock(com.aiwa.service.SmsService.class);
        org.springframework.test.util.ReflectionTestUtils.setField(controller, "smsService", sms);
        when(encoder.encode(anyString())).thenReturn("newhash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        User noContact = User.builder().id(4L).fullName("X").role(UserRole.CUSTOMER).active(true).password("oldhash").build();
        when(userRepo.findById(4L)).thenReturn(Optional.of(noContact));
        assertThatThrownBy(() -> controller.resetPassword(4L, principal("admin@x.com")))
                .isInstanceOf(BusinessException.class).hasMessage("admin.error.reset_no_channel");

        User phoneOnly = User.builder().id(5L).fullName("Y").phone("+201000000010").role(UserRole.CUSTOMER).active(true).password("oldhash").build();
        when(userRepo.findById(5L)).thenReturn(Optional.of(phoneOnly));
        doThrow(new RuntimeException("gateway down")).when(sms).send(anyString(), anyString());
        assertThatThrownBy(() -> controller.resetPassword(5L, principal("admin@x.com")))
                .isInstanceOf(BusinessException.class).hasMessage("admin.error.reset_delivery_failed");
    }

    // ── CR-02: one spelling for every stored phone and email ────────────────

    @Test
    void changingSignInContactsTellsTheUserAndTheOldContacts() {
        // AU-08 / M-3: a silent contact change was half of an insider takeover.
        com.aiwa.service.SmsService sms = mock(com.aiwa.service.SmsService.class);
        com.aiwa.service.EmailService mail = mock(com.aiwa.service.EmailService.class);
        org.springframework.test.util.ReflectionTestUtils.setField(controller, "smsService", sms);
        org.springframework.test.util.ReflectionTestUtils.setField(controller, "emailService", mail);
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com").phone("+201000000001")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        controller.editUser(3L, editReq(null, "new@x.com", "01012345678"), principal("admin@x.com"));

        verify(sms).send(eq("+201000000001"), contains("support changed"));
        verify(mail).send(eq("layla@x.com"), anyString(), contains("support changed"));
        verify(notificationService).send(eq(3L), eq(com.aiwa.enums.NotificationType.ACCOUNT_WARNING),
                anyString(), anyString(), anyString(), anyString(), isNull(), isNull());
    }

    @Test
    void aNameOnlyEditSendsNoContactNotice() {
        com.aiwa.service.SmsService sms = mock(com.aiwa.service.SmsService.class);
        org.springframework.test.util.ReflectionTestUtils.setField(controller, "smsService", sms);
        User customer = User.builder().id(3L).fullName("Layla").phone("+201000000001")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        controller.editUser(3L, editReq("Layla H", null, null), principal("admin@x.com"));
        verifyNoInteractions(sms);
    }

    @Test
    void editUserStoresThePhoneInTheSpellingSignInLooksUp() {
        User customer = User.builder().id(3L).fullName("Layla").phone("+201000000001")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));

        var res = controller.editUser(3L, editReq(null, null, "0101 234-5678"), principal("admin@x.com"));

        assertThat(customer.getPhone()).isEqualTo("+201012345678");
        assertThat(res.getBody().getData().getPhone()).isEqualTo("+201012345678");
    }

    @Test
    void editUserChecksPhoneUniquenessOnTheNormalisedNumber() {
        User customer = User.builder().id(3L).fullName("Layla").phone("+201000000001")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));
        when(userRepo.existsByPhone("+201012345678")).thenReturn(true);

        assertThatThrownBy(() -> controller.editUser(3L, editReq(null, null, "01012345678"), principal("admin@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already in use");
        verify(userRepo, never()).save(any());
    }

    @Test
    void editUserRejectsAnEmailThatIsNotAnEmail() {
        User customer = User.builder().id(3L).fullName("Layla").email("layla@x.com")
                .role(UserRole.CUSTOMER).active(true).build();
        when(userRepo.findById(3L)).thenReturn(Optional.of(customer));

        assertThatThrownBy(() -> controller.editUser(3L, editReq(null, "01012345678", null), principal("admin@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("auth.error.invalid_email");
        verify(userRepo, never()).save(any());
    }

    private void asSuperAdmin() {
        when(userRepo.findByLogin("boss@x.com")).thenReturn(Optional.of(superAdmin(1L, "boss@x.com")));
        when(userRepo.countActiveSuperAdmins()).thenReturn(1L);
        when(encoder.encode(anyString())).thenReturn("hash");
        when(userRepo.save(any(User.class))).thenAnswer(inv -> { User u = inv.getArgument(0); u.setId(9L); return u; });
    }

    @Test
    void createAdminStoresNormalisedEmailAndPhone() {
        asSuperAdmin();
        AdminUserRequest.CreateAdmin req = createReq(List.of("SUPPORT"));
        req.setEmail("  New.Admin@AIWA.com ");
        req.setPhone("01012345678");

        var res = controller.createAdmin(req, principal("boss@x.com"));

        assertThat(res.getBody().getData().getEmail()).isEqualTo("new.admin@aiwa.com");
        assertThat(res.getBody().getData().getPhone()).isEqualTo("+201012345678");
    }

    @Test
    void createAdminRefusesAnEmailThatDiffersOnlyByCase() {
        asSuperAdmin();
        when(userRepo.existsByEmailIgnoreCase("new@aiwa.com")).thenReturn(true);
        AdminUserRequest.CreateAdmin req = createReq(List.of("SUPPORT"));
        req.setEmail("NEW@Aiwa.com");

        assertThatThrownBy(() -> controller.createAdmin(req, principal("boss@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already in use");
        verify(userRepo, never()).save(any());
    }

    @Test
    void createAdminRefusesAPhoneThatExistsInAnotherSpelling() {
        asSuperAdmin();
        when(userRepo.existsByPhone("+201012345678")).thenReturn(true);
        AdminUserRequest.CreateAdmin req = createReq(List.of("SUPPORT"));
        req.setPhone("01012345678");

        assertThatThrownBy(() -> controller.createAdmin(req, principal("boss@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("already in use");
        verify(userRepo, never()).save(any());
    }

    @Test
    void createAdminRejectsAnEmailThatIsNotAnEmail() {
        asSuperAdmin();
        AdminUserRequest.CreateAdmin req = createReq(List.of("SUPPORT"));
        req.setEmail("not-an-email");

        assertThatThrownBy(() -> controller.createAdmin(req, principal("boss@x.com")))
                .isInstanceOf(BusinessException.class)
                .hasMessage("auth.error.invalid_email");
        verify(userRepo, never()).save(any());
    }
}
