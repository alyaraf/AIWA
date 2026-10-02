-- CR-01: sign-in guesses are capped per account. The count lives in the
-- database (not Redis) so the cap still holds during a Redis outage.
ALTER TABLE users ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_failed_login_at  timestamp(6) with time zone;
-- Time step of the last accepted 2FA code: a code is refused the second time.
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_last_used_step   BIGINT;
