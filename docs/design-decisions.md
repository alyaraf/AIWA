# Intentional differences from the prototype

Deliberate differences between the Flutter app and the prototype kit (FE-30, FE-14).
Each one is kept for the reason given; reversing one is a one-line change at the file listed.
Design/product: strike a row to have it reverted.

| Finding | App behaviour | Why it stays | Where |
|---|---|---|---|
| AUTH-07-V1, AUTH-25-F1 | Focused inputs draw a plum700 border | A visible focus state helps accessibility; the kit's own legacy LoginScreen used it | `aiwa_text_field.dart`, `step_header.dart` (EgyptPhoneField), `app_theme.dart` inputDecorationTheme |
| DISC-01-F11 | The bell sends guests to the auth gate | Guests have no notifications; an empty inbox is a dead end | `home_page.dart` bell `onTap` |
| DISC-02-F3 | Discover shows 8 category chips, not 5 | Home's Makeup / Skin / Massage tiles preselect a chip on Discover | `search_page.dart` `_cats` |
| DISC-08-F4 | Cover rating star is gold300, not gold500 | gold500 has poor contrast on the charcoal (male) cover | `provider_detail_page.dart` cover `_CoverMeta` |
| DISC-09-F2 | Service rows show a 2-line description | Providers write descriptions and customers need them to choose | `provider_detail_page.dart` service row |
| DISC-17-F1 | Saved "Browse providers" opens Discover | The kit opens a hard-coded demo provider | `saved_page.dart` |
| BOOK-47-F2 | Bookings "Find a provider" opens Search | Same: the kit's target is a demo id | `my_bookings_page.dart` |

## FE-14 leftovers not built

| Item | Why not |
|---|---|
| 2px scrim blur behind Cancel / Flag sheets | Needs a custom modal route for a 2px effect. Add one if design insists. |
| Text field built-in 14px bottom margin | Forms space fields with the parent `Column(spacing:)`. A built-in margin would double the gap everywhere. |
| StickyBar `children` row helper | The 4 two-button bars already build their own `Row`, so a helper would not shorten them. |
| `aiwa-heart-pop` keyframe | No prototype screen uses it. |
| Shared drop-in helper | Toast and OfflineBanner slide in based on their show/hide state, so a mount-only helper does not fit. The pop-in is shared (`PopIn` in `system_screen.dart`). |
