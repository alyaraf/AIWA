-- CR-03 (2026-10-02 code review): an admin's dispute resolution is recorded on
-- the booking and is final; the customer's "not paid" is accepted once, within
-- a set time after completion. Every statement is additive and safe to re-run.

-- When the provider marked the booking COMPLETED (start of the "not paid" window).
-- Bookings completed before this migration keep NULL: the scheduled end is used.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS completed_at timestamp(6);

-- When the customer reported "not paid" (once per booking).
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS customer_disputed_at timestamp(6);

-- The admin's outcome (PAID | UNPAID | NO_SHOW | CANCEL), when, and who.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_resolution varchar(16);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_resolved_at timestamp(6);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_resolved_by varchar(255);
