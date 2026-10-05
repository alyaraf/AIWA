package com.aiwa.security;

/**
 * Method-security expressions for the admin permission tiers.
 *
 * <p>Every admin (even one with no permissions) may call read-only endpoints
 * ({@link #ANY_ADMIN}). Mutations are gated by capability:
 * <ul>
 *   <li>{@link #SUPPORT} — complaints, flags, warnings, content moderation,
 *       provider verification, customer/provider account suspension.</li>
 *   <li>{@link #FINANCE} — settlements, payouts, commission rate, booking
 *       dispute resolution and force-cancellation.</li>
 *   <li>{@link #SUPER_ADMIN} — other admins &amp; permissions, platform booking
 *       rules, terms/policies, support settings, permanent account deletion.</li>
 * </ul>
 * A {@code SUPER_ADMIN} implicitly holds {@code SUPPORT} and {@code FINANCE}
 * (granted as authorities in {@code UserDetailsServiceImpl}), so the expressions
 * below only need to name the primary capability.
 */
public final class Perms {

    public static final String ANY_ADMIN   = "hasRole('ADMIN')";
    public static final String SUPPORT     = "hasAuthority('PERM_SUPPORT')";
    public static final String FINANCE     = "hasAuthority('PERM_FINANCE')";
    public static final String SUPER_ADMIN = "hasAuthority('PERM_SUPER_ADMIN')";

    /**
     * Sensitive reads and bulk exports. There is no dedicated audit permission, so the audit log
     * is a Super admin read; settlements and the commission ledger are Finance reads; booking
     * lists and exports (customer/provider names, amounts) are Support or Finance. SUPER_ADMIN
     * holds both of those implicitly.
     */
    public static final String AUDIT_READ  = SUPER_ADMIN;
    public static final String FINANCE_READ = FINANCE;
    public static final String SUPPORT_OR_FINANCE = "hasAuthority('PERM_SUPPORT') or hasAuthority('PERM_FINANCE')";

    private Perms() {}
}
