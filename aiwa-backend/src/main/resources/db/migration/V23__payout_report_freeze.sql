-- CR-06 (2026-10-02 code review): the provider's "I paid" report freezes the
-- ledger entries it covers, so finance confirms exactly what was reported.
-- Every statement is additive and safe to re-run.

-- When the provider's report covered this entry (NULL: not part of a report).
ALTER TABLE commission_ledger_entries ADD COLUMN IF NOT EXISTS payout_reported_at timestamp(6);

-- Reports already waiting when this runs: freeze what the old rule would have
-- settled (outstanding entries recorded up to the report time).
UPDATE commission_ledger_entries
SET payout_reported_at = (SELECT p.settlement_reported_at FROM provider_profiles p
                          WHERE p.id = commission_ledger_entries.provider_id)
WHERE payout_reported_at IS NULL
  AND status IN ('DUE', 'OVERDUE')
  AND EXISTS (SELECT 1 FROM provider_profiles p
              WHERE p.id = commission_ledger_entries.provider_id
                AND p.settlement_reported_at IS NOT NULL
                AND commission_ledger_entries.created_at <= p.settlement_reported_at);
