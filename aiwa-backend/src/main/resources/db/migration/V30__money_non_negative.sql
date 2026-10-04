-- Hardening (audit 2026-10-03, database findings): nothing stopped a negative price, fee or
-- commission from reaching the money columns; only the API's validation did.
--
-- NOT VALID, as in V25: rows that already break a rule are left alone and do not stop the
-- migration; new and updated rows are checked. To list offenders and, once corrected, have a
-- constraint cover them too:
--   SELECT id, price FROM services WHERE price < 0;
--   ALTER TABLE services VALIDATE CONSTRAINT chk_services_price_non_negative;
-- Safe to re-run: each constraint is only added when it is missing.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_services_price_non_negative') THEN
        ALTER TABLE services ADD CONSTRAINT chk_services_price_non_negative CHECK (price >= 0) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_bookings_money_non_negative') THEN
        ALTER TABLE bookings ADD CONSTRAINT chk_bookings_money_non_negative
            CHECK (total_price >= 0 AND (travel_fee IS NULL OR travel_fee >= 0)) NOT VALID;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_commission_money_non_negative') THEN
        ALTER TABLE commission_ledger_entries ADD CONSTRAINT chk_commission_money_non_negative
            CHECK (booking_amount >= 0 AND commission_amount >= 0) NOT VALID;
    END IF;
END $$;
