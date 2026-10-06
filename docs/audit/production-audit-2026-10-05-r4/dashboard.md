# Dashboard review — round 4

Baseline 290a05f, 2026-10-05. Source: D:/AIWA PROJECT/AIWA/aiwa-admin-dashboard-updated/src. Fresh verification is source review, 164 existing Vitest tests, production Vite build and three isolated rendered/transport probes. No fresh real-browser session was performed. The previous remediation's browser observations are historical evidence only.

| Screen / shared workflow | Updated behavior assessed | Residual / verification boundary |
| --- | --- | --- |
| Login/profile/session | Memory access token, cookie refresh, logout ordering, idle signal/timer, profile retry | R4-03 already-loaded data after cross-tab identity change; R4-04 body completion |
| Dashboard/inbox/navigation | Capability nav and filtered server inbox | Cross-account subtree remains mounted; counts/aggregate privacy needs deployed policy signoff |
| Safety | Stale/offline/hung-poll banner, last-confirmed time, retry, full details | R4-07 older initial/manual read erases newer poll; R4-02 API address wrong |
| Verifications/private documents | Authorized blob load and provider actions; shared dialogs | R4-04 generation check stops at headers; real crypto/permission/device file smoke needed |
| Complaints/flags | Partial warning/suspension followed by case closure keeps Retry closing state | Provider/notification delivery and real write failure evidence |
| Users/providers | Target/capability controls and keyboard row interaction | Real role/MFA/contact/deletion matrix; stale account view reset R4-03 |
| Bookings | Screen smoke now covers all sidebar routes and prior render crash; status/filter/export | Destination amendment has no mobile UI; route authorization on mounted view |
| Reviews | Hidden state mapped/displayed/restorable/exported | Real DTO and mutation smoke |
| Photo moderation / chat reports | SUPPORT read/action gates and shared dialogs | Private old-row teardown; complete queue paging |
| Settlements/details | Remaining balance actionable after payout; global refresh/error reset tested | Real amount/report freeze/concurrent finance actions and export body guard |
| Audit/exports | Server/client CSV formula controls | R4-04 download after session change; spreadsheet-open verification |
| Policies/support | Draft type/generation and publish loading guards; accurate public support contact copy | Real policy rollout/version acceptance; on-call email is not implemented by this contact field |
| Shared dialogs/toasts | Modal name, focus/Escape/restore, inert base, keyboard controls | Native browser and screen-reader verification, including nested dialogs |
| Shared loaders/refresh | Waits for subscribed loads before success; list truncation notice | 50-page collection remains; server paging/search and actual release check gates |

Fresh probes establish:

1. Resolve private document headers as A, change to B while blob body is pending, complete the body: an A object URL is returned.
2. Load a restricted SOS as A, dispatch a new-session storage event, hydrate Finance B: B's name appears and the restricted SOS remains visible after navigation is hidden.
3. Delay an initial empty SOS response, complete a newer poll with a new incident, then finish the old initial read: the page claims an empty live queue.

See [validation/admin-probes.txt](validation/admin-probes.txt), [validation/sos-probes.txt](validation/sos-probes.txt) and [audit.md](audit.md). No fresh live server authorization failure was reproduced; the cross-account finding concerns client-retained data.
