-- CR-08: SOS texts are retried until the SOS is closed.
-- When an undelivered text is due for its next try (NULL = due now). While a
-- text is being sent this is a short lease, so the sweep leaves it alone.
ALTER TABLE sos_deliveries ADD COLUMN IF NOT EXISTS next_attempt_at timestamp(6);
