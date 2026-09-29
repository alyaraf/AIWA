-- ACCT-21: WhatsApp notification channel preference (kit NOTIF_CHANNELS).
ALTER TABLE users ADD COLUMN IF NOT EXISTS notify_whatsapp boolean NOT NULL DEFAULT false;

-- ADMIN-04: admin-only note on a provider verification case.
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS verification_note varchar(2000);

-- ADMIN-35: terms version history shows a change note and who published it.
ALTER TABLE terms_policies ADD COLUMN IF NOT EXISTS change_note varchar(500);
ALTER TABLE terms_policies ADD COLUMN IF NOT EXISTS published_by varchar(255);
