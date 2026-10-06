# Updated API flow notes

Verified source: ddebaf9, 2026-10-06. [Current static inventory](api-inventory.md). The broader [round 4 flows](../production-audit-2026-10-05-r4/api-flows.md) remain context; only changed flows are described here.

| Flow | Current behavior and available evidence |
| --- | --- |
| Mobile refresh → next protected request | ApiClient refreshes and writes secure storage; auth sign-in uses the new credential lock, refresh does not. R5-01 proves a late A write replaces B's bearer token while B's id/refresh remain. |
| Admin SOS detail/list projection | SafetyService.toAdminDto uses BookingPrivacy.destinationOf and carries snapshot coordinates/provenance. Edited saved-address, amendment and legacy-backfill scenarios pass in backend tests. |
| Admin Complaints / Flags / Reviews | Existing routes now accept server filters/search and bounded page/size; Reviews also accepts maxRating. URL/method capabilities remain; services/repositories search and return actual totals; React usePagedQuery rejects obsolete reads. Search/query-count/paging tests pass. |
| Private document/export download | Admin API helper tracks abortion and checks session generation after consuming the body. Callers create a blob URL/download only from an accepted result. Tests cover body completion after session change. |
| Mobile home-visit destination amendment | Tracking UI → amendment sheet → LiveBookingCubit/repository → existing booking amendment endpoint → snapshot/state/radius/time rules. Six mobile tests and backend snapshot tests pass. |
| Resumed provider setup | Account-bound secure-storage checkpoint → terms/preferences/profile+staff/documents runner → progress checkpoint. Missing photo paths are reported. Host tests exercise interruption/resume; real device lifecycle still open. |
| Backup → recovery evidence | pg_dump → scratch verification → uploads tar → live-reference reconciliation → manifest/metrics. R5-02 demonstrates that the live query is not the dump snapshot. Post-restore reconciliation uses the restored DB and now reports query/terminator failures. |
| Restore → paired undo | Staged files → stopped backend → encrypted safety copy → DB restore → swap → restart. Automatic uncertain rollback stays stopped. Printed successful-restore undo runs a DB-only restore that starts the backend before the file rollback (R5-03). |

No new production traffic, real provider delivery or live restore was performed. H2 and synthetic integration tests are not a substitute for PostgreSQL/Redis, native browser or device evidence.
