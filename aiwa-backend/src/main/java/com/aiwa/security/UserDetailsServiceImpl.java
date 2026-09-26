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
        User user = userRepository.findByEmail(identifier)
                .or(() -> userRepository.findByPhone(identifier))
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + identifier));

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

        return new org.springframework.security.core.userdetails.User(
                identifier,
                user.getPassword(),
                user.isActive(),
                true, true, true,
                authorities
        );
    }
}
