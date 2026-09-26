-- Admin-editable booking rules (null = fall back to config defaults)
ALTER TABLE platform_settings ADD COLUMN IF NOT EXISTS cancellation_cutoff_hours        integer;
ALTER TABLE platform_settings ADD COLUMN IF NOT EXISTS provider_cancel_penalty_percent  numeric(5,2);
ALTER TABLE platform_settings ADD COLUMN IF NOT EXISTS response_window_minutes          bigint;
