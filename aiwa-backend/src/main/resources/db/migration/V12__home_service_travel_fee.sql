-- Flat per-provider home-service travel fee (option A).
-- Snapshotted onto each home-service booking at creation so provider profile
-- edits don't retroactively change historical receipts. Commission is charged
-- on (total_price - travel_fee), i.e. the service portion only.

ALTER TABLE provider_profiles
    ADD COLUMN IF NOT EXISTS home_service_travel_fee DECIMAL(10, 2);

ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS travel_fee DECIMAL(10, 2);
