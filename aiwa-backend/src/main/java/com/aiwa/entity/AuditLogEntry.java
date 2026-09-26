package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;

/** Immutable record of a privileged admin action, for accountability. */
@Entity
@Table(name = "audit_log", indexes = @Index(name = "idx_audit_created", columnList = "created_at"))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AuditLogEntry extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Who performed the action (admin display name or identifier). */
    @Column(nullable = false)
    private String actor;

    /** Machine-readable action key, e.g. PROVIDER_APPROVED. */
    @Column(nullable = false)
    private String action;

    /** Human-readable target label, e.g. "Nadia Studio" or "admin2@aiwa.com". */
    private String target;

    /** Best-effort client IP captured at request time. */
    private String ipAddress;
}
