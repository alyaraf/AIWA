-- CR-13(b) (2026-10-02 code review): a service lasts less than a day. From 24
-- hours the end time stored on its bookings wraps past midnight and hides them
-- from the overlap check (rest of DR-012). The API's own limit is lower
-- (ServiceRequest: 480 minutes); this is the guard for anything that gets past it.
--
-- NOT VALID: rows that already break the rule are left as they are (nothing is
-- clamped) and do not stop the migration; new and updated rows are checked.
-- To list them and, once corrected, have the constraint cover them too:
--   SELECT id, provider_id, name, duration_minutes FROM services WHERE duration_minutes >= 1440;
--   ALTER TABLE services VALIDATE CONSTRAINT chk_services_duration_max;
-- Safe to re-run: the constraint is only added when it is missing.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_services_duration_max') THEN
        ALTER TABLE services ADD CONSTRAINT chk_services_duration_max
            CHECK (duration_minutes < 1440) NOT VALID;
    END IF;
END $$;
