-- CR-13(f): the instant a pending request's answer clock last (re)started, stored
-- with its time zone. The local-time columns it complements (created_at,
-- proposed_at, awaiting_since) are ambiguous in the repeated autumn hour, so a
-- request written then could expire up to an hour early. Optional: rows written
-- before this migration keep using the local-time columns.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS waiting_since_instant timestamp(6) with time zone;
