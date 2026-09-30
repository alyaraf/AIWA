package com.aiwa.security;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.User;

import java.time.Instant;
import java.util.Collection;

/**
 * Spring's {@link User} plus the account's session cut-off: tokens issued
 * before {@code tokensValidAfter} (set on password reset / admin deactivation)
 * are rejected even though their signature and expiry are still fine.
 */
public class AiwaUserDetails extends User {

    private final Instant tokensValidAfter;
    private final Long userId;

    public AiwaUserDetails(String username, String password, boolean enabled,
                           Collection<? extends GrantedAuthority> authorities,
                           Instant tokensValidAfter) {
        this(null, username, password, enabled, authorities, tokensValidAfter);
    }

    public AiwaUserDetails(Long userId, String username, String password, boolean enabled,
                           Collection<? extends GrantedAuthority> authorities,
                           Instant tokensValidAfter) {
        super(username, password, enabled, true, true, true, authorities);
        this.userId = userId;
        this.tokensValidAfter = tokensValidAfter;
    }

    public Long getUserId() {
        return userId;
    }

    /**
     * The signed-in user's id straight from the principal the JWT filter built,
     * so controllers skip a second users lookup per request (BE-39). Null for
     * principals that don't carry it (e.g. @WithMockUser in tests); callers
     * then fall back to looking the user up by name.
     */
    public static Long idOf(org.springframework.security.core.userdetails.UserDetails ud) {
        return ud instanceof AiwaUserDetails a ? a.userId : null;
    }

    public Instant getTokensValidAfter() {
        return tokensValidAfter;
    }

    /** JWT iat has second precision, so compare at that precision. */
    public boolean acceptsTokenIssuedAt(Instant issuedAt) {
        if (tokensValidAfter == null) return true;
        if (issuedAt == null) return false;
        return !issuedAt.isBefore(tokensValidAfter.truncatedTo(java.time.temporal.ChronoUnit.SECONDS));
    }
}
