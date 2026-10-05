-- B-05: a booking keeps its own copy of the visit destination. Editing or archiving a saved address no longer
-- moves an existing booking, and booking history records where the visit was agreed to take place.
-- Additive and nullable, so the previous release keeps working against this schema (rollback: ignore the columns).
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_label varchar(255);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_address varchar(255);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_latitude double precision;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_longitude double precision;
-- true = copied from the saved address as it is NOW, because the original agreed text was never recorded.
-- Such a row may differ from what was agreed if the address was edited before this migration; nothing is invented.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_backfilled boolean NOT NULL DEFAULT false;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS destination_amended_at timestamp(6) with time zone;

UPDATE bookings
   SET destination_label     = (SELECT a.label        FROM saved_addresses a WHERE a.id = bookings.saved_address_id),
       destination_address   = (SELECT a.address_line FROM saved_addresses a WHERE a.id = bookings.saved_address_id),
       destination_latitude  = (SELECT a.latitude     FROM saved_addresses a WHERE a.id = bookings.saved_address_id),
       destination_longitude = (SELECT a.longitude    FROM saved_addresses a WHERE a.id = bookings.saved_address_id),
       destination_backfilled = true
 WHERE saved_address_id IS NOT NULL AND destination_address IS NULL;
