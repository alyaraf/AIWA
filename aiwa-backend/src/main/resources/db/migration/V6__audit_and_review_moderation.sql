-- Admin audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id         bigserial PRIMARY KEY,
    actor      varchar(255) NOT NULL,
    action     varchar(255) NOT NULL,
    target     varchar(255),
    ip_address varchar(64),
    created_at timestamp NOT NULL DEFAULT now(),
    updated_at timestamp
);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_log (created_at DESC);

-- Review moderation: hide/unhide (excluded from public listing + rating)
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS hidden boolean NOT NULL DEFAULT false;
