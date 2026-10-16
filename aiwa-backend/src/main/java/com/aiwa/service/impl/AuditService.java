package com.aiwa.service.impl;

import com.aiwa.entity.AuditLogEntry;
import com.aiwa.repository.AuditLogRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
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

    /**
     * Records an action performed by the current authenticated admin.
     * L-4: in its own transaction, so a failed audit insert can't mark the admin
     * action's transaction rollback-only and turn it into a 500 at commit.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String action, String target) {
        record(currentActor(), action, target);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String actor, String action, String target) {
        try {
            repo.save(AuditLogEntry.builder()
                    .actor(actor != null ? actor : "system")
                    .action(action)
                    .target(target)
                    .ipAddress(currentIp())
                    .build());
        } catch (Exception ex) {
            log.warn("Failed to write audit entry {} {}: {}", com.aiwa.util.LogSafe.oneLine(action),
                    com.aiwa.util.LogSafe.oneLine(target), ex.getMessage());
        }
    }

    /** AQ-02: how the log names a user account, as actor or target: by id, never by name or contact. */
    public static String userLabel(Long userId) {
        return "user #" + userId;
    }

    private String currentActor() {
        try {
            var auth = SecurityContextHolder.getContext().getAuthentication();
            // AQ-02: a customer or provider is recorded by account id, not the email or phone they signed in
            // with, so the log keeps no contact detail of theirs once the account is deleted.
            if (auth != null && auth.getPrincipal() instanceof com.aiwa.security.AiwaUserDetails u && u.getUserId() != null
                    && auth.getAuthorities().stream().noneMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()))) {
                return userLabel(u.getUserId());
            }
            if (auth != null && auth.getName() != null) return auth.getName();
        } catch (Exception ignored) { }
        return "system";
    }

    private String currentIp() {
        try {
            var attrs = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
            if (attrs != null) {
                var request = attrs.getRequest();
                // L-3: the remote address only. In prod Tomcat's RemoteIpValve has already
                // resolved it from the X-Forwarded-For the trusted proxy (Caddy) set; reading
                // the header here let any client that reached the container forge it.
                return request.getRemoteAddr();
            }
        } catch (Exception ignored) { }
        return null;
    }
}
