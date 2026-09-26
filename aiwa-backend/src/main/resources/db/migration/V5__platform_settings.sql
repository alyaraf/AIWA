-- Admin-editable platform settings (single row). Seeds the commission rate at 10%.
CREATE TABLE IF NOT EXISTS platform_settings (
    id                 bigserial PRIMARY KEY,
    commission_percent numeric(5,2) NOT NULL,
    created_at         timestamp NOT NULL DEFAULT now(),
    updated_at         timestamp
);

INSERT INTO platform_settings (commission_percent, created_at)
SELECT 10.00, now()
WHERE NOT EXISTS (SELECT 1 FROM platform_settings);
