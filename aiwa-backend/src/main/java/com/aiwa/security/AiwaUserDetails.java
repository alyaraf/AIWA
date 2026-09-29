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

    public AiwaUserDetails(String username, String password, boolean enabled,
                           Collection<? extends GrantedAuthority> authorities,
                           Instant tokensValidAfter) {
        super(username, password, enabled, true, true, true, authorities);
        this.tokensValidAfter = tokensValidAfter;
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
