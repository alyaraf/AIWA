-- Provider-proposed alternative slot (awaiting customer accept/decline).
-- New booking lifecycle values (EXPIRED) and notification types are stored as
-- VARCHAR via @Enumerated(STRING) and need no DDL.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS proposed_date       date;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS proposed_start_time time;
