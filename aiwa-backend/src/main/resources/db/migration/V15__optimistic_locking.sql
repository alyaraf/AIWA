-- BE-38: optimistic locking. Two simultaneous status changes on one booking
-- (e.g. provider Accept vs customer Cancel) used to both pass their checks and
-- the later save silently won. Hibernate now bumps these on every update and
-- rejects a stale write (returned to the client as 409).
ALTER TABLE bookings ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
ALTER TABLE provider_profiles ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
