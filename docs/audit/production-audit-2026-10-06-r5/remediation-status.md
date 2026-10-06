# Round 5 closure reconciliation

Baseline: committed round 4 remediation at ddebaf9, verified 2026-10-06. Read [audit.md](audit.md) for findings/evidence. This table updates the remediation record without editing its historical claims.

| Earlier item | Current assessment | Reason |
| --- | --- | --- |
| B-05 / R4-02 / FU-1 | Fixed in available local evidence | Frozen SOS projection and mobile amendment now tested; actual PostgreSQL migration and devices remain gates |
| M-01 / R4-05 | **Partial** | New stale-auth scenarios pass, but R5-01 allows an obsolete refresh to corrupt a newer account's credentials |
| M-05 / FU-2 | Fixed in reviewed checkpoint flow; device evidence open | Durable post-registration checkpoint/resume tested; no real process-kill/device proof |
| M-07 / FU-5 | Fixed in available local evidence | Failed newer-terms reload no longer leaves old text/Continue |
| AD-04 / R4-03 / R4-04 | Fixed in reviewed source/jsdom scenarios; browser evidence open | Cross-tab reset, loading permissions and post-body blob check present |
| AD-05 / R4-07 | Fixed in available local evidence | Initial/manual/poll read ordering unified and tested |
| AD-13 / FU-4 | **Mitigated** | Three of nine queues server-paged; six retain collection caps |
| I-02 / R4-01 | **Partial** | Automatic failed rollback is safe in the harness; documented paired undo still has R5-03 |
| I-03 / FU-3 | **Partial mitigation** | Failed/incomplete query detection improved, but backup-time clean-pair signal is invalid (R5-02); coordinated snapshots are not implemented |
| I-05 | **External / blocked** | Bucket/IAM/lifecycle/immutability/offsite/key-escrow evidence absent |
| R4-06 | Fixed for new copies; deployed migration and modes open | Encryption/retention pass locally; legacy plaintext copies and Linux modes need operators/staging |
| R4-08 | Fixed in source; CI execution open | Full release gate and five negative graph checks pass locally |
| P-07 / FU-6 receipt contract | **Mitigated** | Optional receipt path tested; provider-specific acceptance/delivery requires sandbox |
| P-03 / browser/device follow-ups | Open external evidence | No fresh native two-tab, accessibility or device execution |
| AU-11 / dependency advisory gate | Gate retained; **fails on current registry data** | R5-04: build dependency source-map-js 1.2.1 has a High-rated upstream advisory; no running-dashboard exploit established |
| Other previously fixed findings | No newly established regression in the reviewed paths | Earlier record retained; available full suites rerun. This is not a fresh independent runtime verification of every old finding. |

Do not total this table as a new exhaustive 38-finding certification: it identifies changed closure decisions and preserves the original status history. The four R5 findings are 1 High / 3 Medium at repository scope; R5-04's upstream advisory is High. All 40 launch evidence rows remain incomplete.
