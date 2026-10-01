package com.aiwa.entity;

import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.domain.Persistable;

import java.time.Instant;

/**
 * A logged-out or spent token, by SHA-256 (DR-002). Kept in the database as
 * well as Redis, so revocation and refresh-token reuse checks still hold while
 * Redis is down. Rows are removed once the token would have expired anyway.
 */
@Entity
@Table(name = "revoked_tokens")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class RevokedToken implements Persistable<String> {

    @Id
    @Column(name = "token_hash", length = 64)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    /** Always an INSERT: a second claim of the same token must fail on the primary key. */
    @Override
    public String getId() {
        return tokenHash;
    }

    @Override
    public boolean isNew() {
        return true;
    }
}
