-- DR-002: revoked and spent tokens are also kept in the database, so logout and
-- refresh-token reuse checks still work while Redis is down. Rows are deleted
-- once the token would have expired anyway.
CREATE TABLE IF NOT EXISTS revoked_tokens (
    token_hash varchar(64)  PRIMARY KEY,
    expires_at timestamp(6) with time zone NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_revoked_tokens_expires ON revoked_tokens (expires_at);
