-- F-17: a temporary password issued by support stops working after this instant (24 h by default), so a
-- password that was texted or emailed does not stay valid until someone happens to change it. Cleared when
-- the user sets their own password (forgot-password flow). Null = the password never expires.
ALTER TABLE users ADD COLUMN IF NOT EXISTS temp_password_expires_at timestamp(6) with time zone;
