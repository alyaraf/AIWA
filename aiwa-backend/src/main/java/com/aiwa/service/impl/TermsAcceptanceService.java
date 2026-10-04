package com.aiwa.service.impl;

import com.aiwa.entity.TermsAcceptance;
import com.aiwa.entity.User;
import com.aiwa.enums.UserRole;
import com.aiwa.repository.TermsAcceptanceRepository;
import com.aiwa.repository.TermsPolicyRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * AU-19 (owner rule 2026-10-04): terms acceptance per document type. A user is up to
 * date when they accepted the live version of their role's main document; admins
 * always are, and so is everyone while no version of that document is published.
 */
@Service
@RequiredArgsConstructor
public class TermsAcceptanceService {

    private final TermsAcceptanceRepository acceptances;
    private final TermsPolicyRepository policies;

    public static String mainDocumentOf(UserRole role) {
        return role == UserRole.PROVIDER ? "PROVIDER_TERMS" : "CUSTOMER_TERMS";
    }

    @Transactional(readOnly = true)
    public boolean isUpToDate(User user) {
        return isUpToDate(user.getId(), user.getRole());
    }

    @Transactional(readOnly = true)
    public boolean isUpToDate(Long userId, UserRole role) {
        if (role == UserRole.ADMIN) return true;
        String type = mainDocumentOf(role);
        return policies.findFirstByTypeAndActiveTrueOrderByCreatedAtDescIdDesc(type)
                .map(live -> acceptances.findByUserIdAndType(userId, type)
                        .map(a -> live.getVersion().equals(a.getVersion()))
                        .orElse(false))
                .orElse(true);
    }

    /** Records the accepted version of one document type (insert or replace). */
    @Transactional
    public void accept(User user, String type, String version) {
        TermsAcceptance row = acceptances.findByUserIdAndType(user.getId(), type)
                .orElseGet(() -> TermsAcceptance.builder().userId(user.getId()).type(type).build());
        row.setVersion(version);
        row.setAcceptedAt(LocalDateTime.now());
        acceptances.save(row);
    }
}
