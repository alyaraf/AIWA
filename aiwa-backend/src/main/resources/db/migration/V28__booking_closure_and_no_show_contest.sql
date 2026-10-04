-- AU-03 (owner rules 2026-10-04):
--  closure_flagged_at: when the closure sweep put an accepted / on-the-way /
--    arrived booking whose slot ended over a day ago in front of the admins
--    (sent once; the admin closes it from Bookings).
--  no_show_contested_at: when the customer contested a no-show, which opened a
--    payment dispute for finance. Once per booking.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS closure_flagged_at   timestamp(6);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS no_show_contested_at timestamp(6);
