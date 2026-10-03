-- CR-16: when the SOS location fix was taken and how accurate it is (metres),
-- so support can tell a fresh position from an old one. Both optional: older
-- apps don't send them.
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS location_time     timestamp(6) with time zone;
ALTER TABLE safety_events ADD COLUMN IF NOT EXISTS location_accuracy double precision;
