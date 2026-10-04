-- SA-07: the commission rate in force when the booking was made. Completion charges this rate, so a
-- later change to the platform or provider rate applies to future bookings only, as the admin panel
-- says. Bookings made before this migration have no snapshot and keep using the current rate.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_percent_at_booking numeric(5, 2);
