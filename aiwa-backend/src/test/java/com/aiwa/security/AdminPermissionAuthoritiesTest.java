package com.aiwa.security;

import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.EnumSet;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * A SUPPORT admin must not receive FINANCE / SUPER_ADMIN authorities; a
 * SUPER_ADMIN implicitly receives every tier.
 */
class AdminPermissionAuthoritiesTest {

    private final UserRepository userRepo = mock(UserRepository.class);
    private final UserDetailsServiceImpl service = new UserDetailsServiceImpl(userRepo);

    private Set<String> authoritiesFor(User user) {
        when(userRepo.findByEmail("x@aiwa.com")).thenReturn(Optional.of(user));
        UserDetails details = service.loadUserByUsername("x@aiwa.com");
        return details.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toSet());
    }

    private User admin(Set<AdminPermission> perms) {
        return User.builder()
                .id(1L).email("x@aiwa.com").password("h")
                .role(UserRole.ADMIN).active(true)
                .adminPermissions(perms)
                .build();
    }

    @Test
    void supportAdminGetsOnlySupport() {
        Set<String> auth = authoritiesFor(admin(EnumSet.of(AdminPermission.SUPPORT)));
        assertThat(auth).contains("ROLE_ADMIN", "PERM_SUPPORT");
        assertThat(auth).doesNotContain("PERM_FINANCE", "PERM_SUPER_ADMIN");
    }

    @Test
    void financeAdminGetsOnlyFinance() {
        Set<String> auth = authoritiesFor(admin(EnumSet.of(AdminPermission.FINANCE)));
        assertThat(auth).contains("PERM_FINANCE");
        assertThat(auth).doesNotContain("PERM_SUPPORT", "PERM_SUPER_ADMIN");
    }

    @Test
    void superAdminGetsEveryTier() {
        Set<String> auth = authoritiesFor(admin(EnumSet.of(AdminPermission.SUPER_ADMIN)));
        assertThat(auth).contains("PERM_SUPER_ADMIN", "PERM_SUPPORT", "PERM_FINANCE");
    }

    @Test
    void customerGetsNoPermAuthorities() {
        User customer = User.builder().id(2L).email("x@aiwa.com").password("h")
                .role(UserRole.CUSTOMER).active(true).build();
        Set<String> auth = authoritiesFor(customer);
        assertThat(auth).containsExactly("ROLE_CUSTOMER");
    }
}
