-- A re-started 2FA setup keeps the confirmed secret (and 2FA) on until the new secret's first
-- code arrives; the new one waits here. Before, setup switched 2FA off for that window, so the
-- password alone could sign in and enrol another authenticator.
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_pending_secret varchar(255);
-- Enrollments in progress (2FA off, secret not yet confirmed) move to the new column.
UPDATE users SET totp_pending_secret = totp_secret, totp_secret = NULL
WHERE totp_enabled = false AND totp_secret IS NOT NULL;
