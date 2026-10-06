-- SEC-03: a 2FA enrollment is pending only for a limited time and a limited number of
-- confirmation attempts. The counters live in the database so the cap holds across IPs,
-- instances and a Redis outage.
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_enrollment_expires_at  timestamp(6) with time zone;
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_enrollment_attempts    INTEGER NOT NULL DEFAULT 0;
