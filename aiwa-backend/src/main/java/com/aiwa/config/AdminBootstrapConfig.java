package com.aiwa.config;

import com.aiwa.entity.User;
import com.aiwa.enums.Language;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class AdminBootstrapConfig implements ApplicationRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${aiwa.admin.email:}")
    private String adminEmail;

    @Value("${aiwa.admin.phone:}")
    private String adminPhone;

    @Value("${aiwa.admin.password:}")
    private String adminPassword;

    @Value("${aiwa.admin.full-name:AIWA Admin}")
    private String adminFullName;

    @Override
    public void run(ApplicationArguments args) {
        if (userRepository.findByRoleOrderByCreatedAtDesc(UserRole.ADMIN, org.springframework.data.domain.PageRequest.of(0, 1)).hasContent()) {
            return;
        }
        if ((adminEmail == null || adminEmail.isBlank()) && (adminPhone == null || adminPhone.isBlank())) {
            log.warn("No admin user exists. Set ADMIN_EMAIL or ADMIN_PHONE plus ADMIN_PASSWORD to bootstrap the first admin.");
            return;
        }
        if (adminPassword == null || adminPassword.length() < 12) {
            throw new IllegalStateException("ADMIN_PASSWORD must be at least 12 characters when bootstrapping the first admin");
        }
        if (adminEmail != null && !adminEmail.isBlank() && userRepository.existsByEmail(adminEmail)) {
            log.warn("ADMIN_EMAIL already exists, skipping admin bootstrap");
            return;
        }
        if (adminPhone != null && !adminPhone.isBlank() && userRepository.existsByPhone(adminPhone)) {
            log.warn("ADMIN_PHONE already exists, skipping admin bootstrap");
            return;
        }

        User admin = User.builder()
                .fullName(adminFullName)
                .email(blankToNull(adminEmail))
                .phone(blankToNull(adminPhone))
                .password(passwordEncoder.encode(adminPassword))
                .role(UserRole.ADMIN)
                .preferredLanguage(Language.EN)
                .active(true)
                .termsAccepted(true)
                .adminPermissions(new java.util.HashSet<>(java.util.EnumSet.allOf(com.aiwa.enums.AdminPermission.class)))
                .build();

        userRepository.save(admin);
        log.info("Bootstrapped first admin user: {}", admin.getEmail() != null ? admin.getEmail() : admin.getPhone());
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value;
    }
}
