-- Bundle A: booking penalty + denormalized commission for display
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS penalty_applied  boolean       NOT NULL DEFAULT false;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commission_amount numeric(10,2);

-- Bundle B: per-user notification preferences (channels + quiet hours)
ALTER TABLE users ADD COLUMN IF NOT EXISTS notify_push       boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS notify_email      boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS notify_sms        boolean NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mute_all          boolean NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS quiet_hours_start time;
ALTER TABLE users ADD COLUMN IF NOT EXISTS quiet_hours_end   time;

-- Bundle D: per-staff availability + staff skills
ALTER TABLE staff_members ADD COLUMN IF NOT EXISTS skills varchar(255);
ALTER TABLE availabilities ADD COLUMN IF NOT EXISTS staff_member_id bigint;

DO $$
DECLARE
    legacy_constraint text;
BEGIN
    -- add FK once
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_availability_staff_member'
    ) THEN
        ALTER TABLE availabilities
            ADD CONSTRAINT fk_availability_staff_member
            FOREIGN KEY (staff_member_id) REFERENCES staff_members (id);
    END IF;

    -- drop any legacy unique on (provider_id, day_of_week) so multiple staff can share a day
    FOR legacy_constraint IN
        SELECT tc.constraint_name
        FROM information_schema.table_constraints tc
        WHERE tc.table_name = 'availabilities' AND tc.constraint_type = 'UNIQUE'
          AND NOT EXISTS (
              SELECT 1 FROM information_schema.constraint_column_usage x
              WHERE x.constraint_name = tc.constraint_name AND x.column_name = 'staff_member_id')
    LOOP
        EXECUTE 'ALTER TABLE availabilities DROP CONSTRAINT ' || quote_ident(legacy_constraint);
    END LOOP;
END $$;

-- Uniqueness across provider + (staff or provider-level) + day; COALESCE folds NULL staff rows.
CREATE UNIQUE INDEX IF NOT EXISTS ux_availability_provider_staff_day
    ON availabilities (provider_id, COALESCE(staff_member_id, -1), day_of_week);
