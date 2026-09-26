-- Per-provider overrides for commission and booking rules (null = use the platform setting).
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS commission_override_percent              numeric(5,2);
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS cancellation_cutoff_hours_override       integer;
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS provider_cancel_penalty_percent_override numeric(5,2);
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS response_window_minutes_override         bigint;

-- Multiple published support lines. One enabled row per settings record is primary.
CREATE TABLE IF NOT EXISTS support_numbers (
    support_settings_id bigint  NOT NULL REFERENCES support_settings (id) ON DELETE CASCADE,
    sort_order          integer NOT NULL,
    label               varchar(255),
    number              varchar(255) NOT NULL,
    display_number      varchar(255),
    is_primary          boolean NOT NULL DEFAULT false,
    enabled             boolean NOT NULL DEFAULT true,
    PRIMARY KEY (support_settings_id, sort_order)
);

-- Backfill: carry any existing single WhatsApp number into the new list as the primary line.
INSERT INTO support_numbers (support_settings_id, sort_order, label, number, display_number, is_primary, enabled)
SELECT s.id, 0, 'General', s.whatsapp_number,
       COALESCE(NULLIF(s.whatsapp_number_display, ''), s.whatsapp_number),
       true, true
FROM support_settings s
WHERE s.whatsapp_number IS NOT NULL AND s.whatsapp_number <> ''
  AND NOT EXISTS (SELECT 1 FROM support_numbers n WHERE n.support_settings_id = s.id);
