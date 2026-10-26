-- A24-02: every 2FA enrollment has its own identity. Attempts, cancellation and completion are bound to it, so an
-- old confirmation cannot complete, spend the budget of, or cancel the setup that replaced it. A setup that was
-- pending before this migration has no identity and must be started again.
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_enrollment_id varchar(64);
