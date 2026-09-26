-- Customer venue check-in timestamp.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS checked_in_at timestamp;
