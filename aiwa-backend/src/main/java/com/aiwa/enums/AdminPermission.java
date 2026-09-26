package com.aiwa.enums;

/**
 * Fine-grained capabilities for ADMIN-role users. An admin with no permissions
 * can view but not act; SUPER_ADMIN is required to create admins or change
 * another admin's permissions.
 */
public enum AdminPermission {
    /** Chat moderation, complaints, flags. */
    SUPPORT,
    /** Payment disputes, settlements. */
    FINANCE,
    /** Create admins, manage permissions — the highest tier. */
    SUPER_ADMIN
}
