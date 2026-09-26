-- Push device registration. Without these columns there was nowhere to store
-- "this phone's address", so a real-time push notification had no destination —
-- the in-app inbox worked, but the OS-level push that buzzes the phone never fired.
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_token    varchar(512);
ALTER TABLE users ADD COLUMN IF NOT EXISTS push_platform varchar(16);
