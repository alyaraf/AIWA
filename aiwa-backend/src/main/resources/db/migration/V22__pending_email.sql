-- CR-05: an email address the owner has not confirmed with a code yet. It waits
-- here and only moves to users.email on confirmation, so it cannot sign in,
-- reset a password or block someone else's sign-up. Not unique on purpose:
-- naming an address claims nothing.
-- Emails already in users.email stay as they are (it is not known which were verified).
ALTER TABLE users ADD COLUMN IF NOT EXISTS pending_email VARCHAR(255);
