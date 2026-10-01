-- Fixes from the 2026-10-01 deployment-readiness review (docs: release notes in
-- docs/release.md). Every statement is additive and safe to re-run.

-- R2-01: when a booking last went back to "waiting for the provider" (a
-- reschedule). The expiry sweep measures the response window from here, so a
-- rescheduled booking that was accepted days ago is not expired at once.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS awaiting_since timestamp(6);

-- R2-06: a reminder is sent once per booking.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS reminder_sent_at timestamp(6);

-- DR-024: the client's idempotency key is kept with the booking itself.
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS idempotency_key varchar(100);
CREATE UNIQUE INDEX IF NOT EXISTS ux_bookings_customer_idem ON bookings (customer_id, idempotency_key);

-- R2-09 / BE-38: optimistic locking on ledger entries; DR-031: on users.
ALTER TABLE commission_ledger_entries ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0;

-- R2-12: one row per phone instead of one token per user.
CREATE TABLE IF NOT EXISTS push_devices (
    id         bigserial PRIMARY KEY,
    user_id    bigint       NOT NULL REFERENCES users (id),
    token      varchar(512) NOT NULL,
    platform   varchar(16),
    created_at timestamp(6) NOT NULL DEFAULT now(),
    updated_at timestamp(6)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_push_devices_token ON push_devices (token);
CREATE INDEX IF NOT EXISTS idx_push_devices_user ON push_devices (user_id);

-- Carry existing registrations over. A token registered by two accounts goes
-- to the most recently created one.
INSERT INTO push_devices (user_id, token, platform, created_at)
SELECT MAX(u.id), u.push_token, MAX(u.push_platform), now()
FROM users u
WHERE u.push_token IS NOT NULL AND u.push_token <> ''
  AND NOT EXISTS (SELECT 1 FROM push_devices d WHERE d.token = u.push_token)
GROUP BY u.push_token;

-- BE-37 / R2-03: per-recipient SOS delivery state.
CREATE TABLE IF NOT EXISTS sos_deliveries (
    id              bigserial PRIMARY KEY,
    safety_event_id bigint       NOT NULL REFERENCES safety_events (id),
    recipient_kind  varchar(16)  NOT NULL,
    phone           varchar(32)  NOT NULL,
    status          varchar(16)  NOT NULL,
    attempts        integer      NOT NULL DEFAULT 0,
    last_error      varchar(255),
    created_at      timestamp(6) NOT NULL DEFAULT now(),
    updated_at      timestamp(6)
);
CREATE INDEX IF NOT EXISTS idx_sos_deliveries_event ON sos_deliveries (safety_event_id);

