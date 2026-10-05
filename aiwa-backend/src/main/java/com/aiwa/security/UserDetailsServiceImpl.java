package com.aiwa.security;

import com.aiwa.entity.User;
import com.aiwa.enums.AdminPermission;
import com.aiwa.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(String identifier) throws UsernameNotFoundException {
        User user = userRepository.findByLogin(identifier)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + identifier));
        return toDetails(user, identifier);
    }

    /**
     * Load by the token's userId claim when its subject no longer matches — the
     * user changed the email they signed in with. The principal name becomes the
     * account's current email (or phone), which is what controllers look up by.
     */
    @Transactional(readOnly = true)
    public UserDetails loadUserById(Long userId) throws UsernameNotFoundException {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: #" + userId));
        String current = user.getEmail() != null ? user.getEmail() : user.getPhone();
        if (current == null) throw new UsernameNotFoundException("User has no identifier: #" + userId);
        return toDetails(user, current);
    }

    /** Shaped like a BCrypt hash so the encoder compares and fails quietly; no password produces it. */
    private static final String EXPIRED_PASSWORD_HASH = "$2a$10$" + "A".repeat(53);

    private UserDetails toDetails(User user, String identifier) {
        List<GrantedAuthority> authorities = new ArrayList<>();
        authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()));

        // Fine-grained admin capabilities -> "PERM_*" authorities. SUPER_ADMIN is the
        // highest tier and implicitly carries SUPPORT + FINANCE.
        if (user.getAdminPermissions() != null) {
            for (AdminPermission permission : user.getAdminPermissions()) {
                authorities.add(new SimpleGrantedAuthority("PERM_" + permission.name()));
            }
            if (user.getAdminPermissions().contains(AdminPermission.SUPER_ADMIN)) {
                authorities.add(new SimpleGrantedAuthority("PERM_SUPPORT"));
                authorities.add(new SimpleGrantedAuthority("PERM_FINANCE"));
            }
        }

        return new AiwaUserDetails(
                user.getId(),
                identifier,
                // F-17: an expired temporary password no longer matches anything (an unusable bcrypt-shaped value).
                user.hasExpiredTempPassword() ? EXPIRED_PASSWORD_HASH : user.getPassword(),
                user.isActive(),
                authorities,
                user.getTokensValidAfter()
        );
    }
}
