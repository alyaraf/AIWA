# Round 6 flow notes

Source: b2d70b9, 2026-10-06. [Current static inventory](api-inventory.md). [Round 5 context](../production-audit-2026-10-06-r5/api-flows.md).

| Flow | Verified change / remaining issue |
| --- | --- |
| Mobile refresh → credentials | Session-aware storeRefreshedTokens and clearIfSession share the sign-in/logout credential lock; delayed access/refresh tests pass. |
| Mobile failed response → global app event | A delayed A 423 bypasses the 401-specific generation guard and reaches the unowned status stream. _ThemedAppState dispatches logout for current B; R6-02 proves the storage/bloc effect. |
| Backup dump → reference list → archive consistency | Dump is scratch-restored and queried with that scratch DB selected. Its saved references are checked against tar entries, without live fallback. Still separate dump/files snapshots. |
| Restore → --undo → restart | Both halves are restored while stopped, successful completion starts once. A retry entering from incomplete recovery can restart from a failed safety-copy abort before repairing anything (R6-01). |
| Verification / Photo / Chat / Reported reviews / Settlements | Existing routes take server query/filters/page parameters and return real totals. H2 tests cover search/count/permission paths; React tests cover paging/actions/refill/errors. PostgreSQL plans and scale unverified. |
| SOS page/search → global oldest banner | Existing queue accepts newest/oldest order. The adapter fetches oldest separately for larger/matching searches, but skips it when filtered total is zero (R6-03). Sequence/context guards retain accepted-read ordering. |

No new REST handler was added; 183 handlers in 29 controllers were inventoried statically. This does not prove every endpoint's runtime behavior or framework/ORM side effects. Full production/device/provider paths were not exercised.
