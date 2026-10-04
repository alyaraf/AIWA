-- SA-08: the pause for repeated cancellations (AU-07) and the pause for unpaid commission used the
-- same flag, so confirming one penalty payment lifted the review. The disciplinary hold is its own
-- column now; only an admin lifting the pause from the provider's profile clears it.
ALTER TABLE provider_profiles ADD COLUMN IF NOT EXISTS disciplinary_hold boolean NOT NULL DEFAULT false;
