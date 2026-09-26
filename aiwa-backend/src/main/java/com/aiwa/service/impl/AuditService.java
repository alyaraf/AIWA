package com.aiwa.service.impl;

import com.aiwa.entity.AuditLogEntry;
import com.aiwa.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Records privileged admin actions to the audit log. Best-effort: a logging
 * failure must never break the action that triggered it.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditLogRepository repo;

    /** Records an action performed by the current authenticated admin. */
    @Transactional
    public void record(String action, String target) {
        record(currentActor(), action, target);
    }

    @Transactional
    public void record(String actor, String action, String target) {
        try {
            repo.save(AuditLogEntry.builder()
                    .actor(actor != null ? actor : "system")
                    .action(action)
                    .target(target)
                    .ipAddress(currentIp())
                    .build());
        } catch (Exception ex) {
            log.warn("Failed to write audit entry {} {}: {}", action, target, ex.getMessage());
        }
    }

    private String currentActor() {
        try {
            var auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getName() != null) return auth.getName();
        } catch (Exception ignored) { }
        return "system";
    }

    private String currentIp() {
        try {
            var attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs != null) {
                var request = attrs.getRequest();
                String forwarded = request.getHeader("X-Forwarded-For");
                if (forwarded != null && !forwarded.isBlank()) return forwarded.split(",")[0].trim();
                return request.getRemoteAddr();
            }
        } catch (Exception ignored) { }
        return null;
    }
}
