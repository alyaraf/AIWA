# Polish backlog — prov (minor findings)

#### Provider post-sign-in / session-restore routing `PROV-02`
- **[MINOR · content] 'Welcome back' toast after sign-in is missing** `PROV-02-F2`
  - Prototype: prototype.jsx:621 `setToast('Welcome back, Layla.')`
  - Flutter now: sign_in_page.dart:65-73 only navigates; nothing in lib/ calls showSnackBar with a welcome message.
  - Fix: Call a shared top toast (see consistency PROV-C1) with 'Welcome back, ${user.fullName.split(' ').first}.' before context.go(...).

#### Provider Today dashboard (hero header + stat tiles + section structure) `PROV-03`
- **[MINOR · components] Extra sign-out icon button in the hero** `PROV-03-F4`
  - Prototype: provider-screens.jsx:46-52: the hero row holds only the eyebrow/title and `<Avatar name="Nadia" palette="rose" size={44} verified />`. Sign-out is a Profile row (provider-screens.jsx:493).
  - Flutter now: dashboard_page.dart:243-248 `AiwaIconButton(icon: Icons.logout_rounded, variant: AiwaIconButtonVariant.glass, size: 36, onTap: _signOut)`.
  - Fix: Remove the AiwaIconButton and SizedBox (dashboard_page.dart:243-249) once the Provider Profile tab (PROV-29) hosts the 'Sign out' SettingsRow.

#### Provider Today dashboard (hero header + stat tiles + section structure) `PROV-03`
- **[MINOR · tokens] Hero overlay colour, tile blur, star size and label tracking differ** `PROV-03-F5`
  - Prototype: provider-screens.jsx:45 `radial-gradient(circle at 80% 20%, rgba(231,186,182,.3), transparent 55%)`; :56 tile `background: 'rgba(250,245,238,.12)', backdropFilter: 'blur(8px)'`; :66 star svg 14px fill gold300; :58 label `letterSpacing: '0.08em'` (0.88px).
  - Flutter now: dashboard_page.dart:207-211 `AiwaGlow(size: 260, color: AppColors.rose300, opacity: 0.3)` (male #B5A898, not the pink rgba(231,186,182)); :353 `AppColors.bone.withOpacity(0.12)` with no BackdropFilter; :362 `Icons.star_rounded, size: 15`; :386 `letterSpacing: 0.8`.
  - Fix: Wrap the tile Container in `ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: ...))`, set the star size to 14 and letterSpacing to 0.88. Keeping the gender-aware rose300 glow is acceptable; if the prototype hex must be exact, use `const Color(0xFFE7BAB6)`.

#### Provider Today dashboard (hero header + stat tiles + section structure) `PROV-03`
- **[MINOR · components] Verified badge on the hero avatar never renders** `PROV-03-V1`
  - Prototype: provider-screens.jsx:51 `<Avatar name="Nadia" palette="rose" size={44} verified />`: a gold500 check badge with a 2px #fff border (components.jsx:114-124; gold500 male #5C544D / female #C4837A).
  - Flutter now: dashboard_page.dart:198 `final verified = user?.providerProfile?.isApproved ?? false;`. user_model.dart:36-39 only fills providerProfile from json['providerProfile'], which the backend auth UserDto never sends (AuthServiceImpl.java:246-261), so `verified` is always false and AiwaAvatar draws no badge.
  - Fix: Map providerStatus into UserModel (see corrected PROV-02-F1) so isApproved is true for approved providers. Once the approval gate exists, only approved providers reach Today, so `verified: true` is also acceptable.

#### 'New requests' section and booking request card (Decline / Accept) `PROV-05`
- **[MINOR · components] Customer avatar palette cycles instead of plum** `PROV-05-F6`
  - Prototype: provider-screens.jsx:94 `<Avatar name={b.customer} palette="plum" size={42} />`.
  - Flutter now: dashboard_page.dart:526-531 `palette: AvatarPalette.values[index % AvatarPalette.values.length]`.
  - Fix: `palette: AvatarPalette.plum`.

#### 'New requests' section and booking request card (Decline / Accept) `PROV-05`
- **[MINOR · tokens] Card shadow is a stronger double shadow** `PROV-05-F7`
  - Prototype: provider-screens.jsx:92 `boxShadow: '0 1px 2px rgba(74,31,56,.04)'`.
  - Flutter now: dashboard_page.dart:520 `boxShadow: AppTheme.shadow1` = plum700 @0.06 blur 2 + ink @0.04 blur 1 (app_theme.dart:60-71).
  - Fix: `boxShadow: [BoxShadow(color: AppColors.plum700.withOpacity(0.04), blurRadius: 2, offset: const Offset(0, 1))]`.

#### 'New requests' section and booking request card (Decline / Accept) `PROV-05`
- **[MINOR · content] Duration is always minutes ('150 min' instead of '2h 30m')** `PROV-05-F8`
  - Prototype: provider-screens.jsx:6,97 duration '2h 30m', '45 min'.
  - Flutter now: dashboard_page.dart:545 `'${b.serviceName} · ${b.serviceDurationMinutes} min'`.
  - Fix: Add a formatter: `String fmt(int m) => m < 60 ? '$m min' : '${m ~/ 60}h${m % 60 > 0 ? ' ${m % 60}m' : ''}';`.

#### 'New requests' section and booking request card (Decline / Accept) `PROV-05`
- **[MINOR · layout] Gap before the StatusPill is 8px instead of 12px** `PROV-05-V2`
  - Prototype: provider-screens.jsx:93 header row `display: 'flex', alignItems: 'center', gap: 12` (avatar | name column | StatusPill).
  - Flutter now: dashboard_page.dart:553 `const SizedBox(width: 8)` before `StatusPill(status: b.status)`.
  - Fix: Change it to `const SizedBox(width: 12)`.

#### Provider Bookings screen (header + Pending/Upcoming/Past tab row + list) `PROV-08`
- **[MINOR · content] Tab labels differ: 'Done' + 'Cancelled' instead of 'Past'** `PROV-08-F4`
  - Prototype: provider-screens.jsx:159 `[['pending','Pending'],['upcoming','Upcoming'],['past','Past']]`.
  - Flutter now: dashboard_page.dart:38-43 `('PENDING','Pending'), ('ACCEPTED','Upcoming'), ('COMPLETED','Done'), ('CANCELLED','Cancelled')`.
  - Fix: Use three tabs: `('PENDING','Pending'), ('UPCOMING','Upcoming'), ('PAST','Past')`, mapping PAST to COMPLETED (optionally plus CANCELLED/REJECTED/NO_SHOW).

#### Bookings tab: Past `PROV-11`
- **[MINOR · content] Tab label 'Done' instead of 'Past'** `PROV-11-F1`
  - Prototype: provider-screens.jsx:159 `['past','Past']`.
  - Flutter now: dashboard_page.dart:41 `('COMPLETED', 'Done')`.
  - Fix: Rename to 'Past'.

#### Bookings list empty state `PROV-12`
- **[MINOR · components] Full EmptyState (icon circle + serif title + body) instead of a single text line** `PROV-12-F1`
  - Prototype: provider-screens.jsx:170 `<div style={{ textAlign: 'center', padding: 40, color: aiwa.ink3, fontSize: 13 }}>Nothing here yet.</div>`.
  - Flutter now: dashboard_page.dart:139-148 `EmptyState(icon: Icons.event_available_outlined, title: ..., subtitle: ..., compact: true)`.
  - Fix: `Padding(padding: EdgeInsets.all(40), child: Text('Nothing here yet.', textAlign: TextAlign.center, style: AppTextStyles.meta.copyWith(color: AppColors.ink3)))`.

#### Bookings list empty state `PROV-12`
- **[MINOR · tokens] Title renders DM Serif 19 plum900 instead of Plus Jakarta 13 ink3** `PROV-12-F2`
  - Prototype: provider-screens.jsx:170 fontSize 13, color ink3 (body font).
  - Flutter now: empty_state.dart:67-70 `AppTextStyles.h3.copyWith(fontSize: compact ? 19 : 22)`.
  - Fix: Covered by PROV-12-F1.

#### Bookings list empty state `PROV-12`
- **[MINOR · content] Copy differs: 'No new requests' plus a subtitle** `PROV-12-F3`
  - Prototype: provider-screens.jsx:170 'Nothing here yet.' for every tab.
  - Flutter now: dashboard_page.dart:141-146 'No new requests' / 'New booking requests will appear here — reply within 30 minutes to keep your top rating.' and 'Bookings in this status will show up here.'
  - Fix: Use 'Nothing here yet.' for all tabs.

#### Booking detail — job progress stepper and status-advance action bar `PROV-14`
- **[MINOR · content] Helper notes under each step are missing** `PROV-14-F6`
  - Prototype: provider-screens.jsx:205-208,352 notes, e.g. 'Customer gets a push + live tracking starts.' and 'Finish the job, then confirm the cash you received.'
  - Flutter now: dashboard_page.dart:636-678: buttons only, no note text.
  - Fix: Add a `const _notes = {'ACCEPTED': ..., 'ON_THE_WAY': ..., 'ARRIVED': ..., 'IN_PROGRESS': 'Finish the job, then confirm the cash you received.'}` map rendered above the buttons.

#### Booking detail — job progress stepper and status-advance action bar `PROV-14`
- **[MINOR · tokens] Buttons are sm instead of lg; the complete icon is a single check** `PROV-14-F7`
  - Prototype: provider-screens.jsx:354-357 `size="lg"` (15px 26px, 16px text, 18px icon); `icon="check-check"` for Mark completed.
  - Flutter now: dashboard_page.dart:607-613 `size: AiwaButtonSize.sm` (8/14 padding, 13px); :672 `icon: Icons.check_rounded`.
  - Fix: Use AiwaButtonSize.lg in the detail bar and Icons.done_all_rounded for 'Mark completed'.

#### Provider sign-out ConfirmSheet `PROV-32`
- **[MINOR · content] Eyebrow reads 'Sign out' instead of 'Provider account', and the body copy is missing** `PROV-32-F1`
  - Prototype: prototype.jsx:492-493 `eyebrow="Provider account" title="Sign out of AIWA?" confirmLabel="Sign out" body="Your bookings stay exactly as they are. You'll need your number and a code to sign back in."`
  - Flutter now: dashboard_page.dart:82-88 `eyebrow: 'Sign out', title: 'Sign out of AIWA?', confirmLabel: 'Sign out', icon: Icons.logout_rounded` (no body).
  - Fix: `showConfirmSheet(context, eyebrow: 'Provider account', title: 'Sign out of AIWA?', body: "Your bookings stay exactly as they are. You'll need your number and a code to sign back in.", confirmLabel: 'Sign out', danger: false, icon: Icons.logout_rounded)`.

#### Provider sign-out ConfirmSheet `PROV-32`
- **[MINOR · tokens] Sheet shadow colour and opacity differ** `PROV-32-F3`
  - Prototype: states.jsx:240 `boxShadow: '0 -12px 32px rgba(42,19,32,.2)'`.
  - Flutter now: app_theme.dart:44-49 `AppColors.plum700.withOpacity(0.14), blurRadius: 32, offset: Offset(0, -12)`.
  - Fix: `withOpacity(0.2)` on AppColors.plum900 in AppTheme.sheetDecoration.

#### Provider sign-out ConfirmSheet `PROV-32`
- **[MINOR · interaction] Triggered from a hero icon instead of the Profile 'Sign out' row; no 'Signed out.' toast** `PROV-32-F4`
  - Prototype: provider-screens.jsx:493 `{ icon: 'log-out', label: 'Sign out', danger: true, onTap: onSignOut }`; prototype.jsx:491 `onConfirm={() => { setShowSignOut(false); setToast('Signed out.'); }}`.
  - Flutter now: dashboard_page.dart:243-248 glass logout icon in the Today hero; :90-91 `AuthLogoutEvent()` then `context.go(AppRoutes.splash)` with no toast. Going to splash matches the customer sign-out (prototype.jsx:756).
  - Fix: Move the trigger to the Provider Profile SettingsRow (PROV-29) and show the shared toast 'Signed out.' after the navigation.

#### Provider notifications inbox (PROVIDER_NOTIFICATIONS) `PROV-48`
- **[MINOR · components] Settlement, payment-dispute and moderation notifications fall back to generic glyphs** `PROV-48-F2`
  - Prototype: customer-extras.jsx:502-504: pn1 'banknote' (settlement), pn2 'image-off' (moderation), pn3 'alert-triangle' (payment disputed). pn4 'calendar-check', pn5 'star' and pn6 'badge-check' already have equivalent Material glyphs.
  - Flutter now: notifications_page.dart:178-180 `if (t.contains('PAYMENT') || t.contains('SETTLEMENT')) return Icons.receipt_long_outlined;` catches SETTLEMENT_OVERDUE and PAYMENT_DISPUTED (backend NotificationType.java). MODERATION_ACTION matches no branch and falls to Icons.notifications_none_rounded (:190). BOOKING_* -> Icons.event_available_outlined (:175-177) is an acceptable calendar-check equivalent.
  - Fix: In _icon, before the PAYMENT/SETTLEMENT branch: `if (t.contains('DISPUTED')) return Icons.warning_amber_rounded; if (t.startsWith('SETTLEMENT') || t == 'COMMISSION_DUE') return Icons.payments_outlined; if (t.startsWith('MODERATION')) return Icons.hide_image_outlined;`

#### Cross-cutting `-`
- **[MINOR · components] Tab bar is private to the customer shell and cannot be reused for the provider shell** `PROV-C4`
  - Prototype: TabBar (components.jsx:203-237) and ProviderTabBar (provider-screens.jsx:562-596) share one visual spec.
  - Flutter now: shell_page.dart:36-158 `_TabBar` / `_TabItem` are private, with customer routes hard-coded.
  - Fix: Extract to shared/widgets/aiwa_tab_bar.dart with a `List<AiwaTab>` parameter and optional badge; use it in both ShellPage and the new ProviderShellPage.

#### Cross-cutting `-`
- **[MINOR · components] Missing shared primitives the provider screens need: Toggle, Tag, stepper** `PROV-C5`
  - Prototype: states.jsx:209-224 Toggle (42x24, knob 18, warn tone); states.jsx:397-410 Tag (3px 9px, radius 999, 11/700, eight tones); schedule/profile inline 40x22 toggles; travel-buffer stepper (provider-screens.jsx:468-470).
  - Flutter now: lib/shared/widgets has no toggle, tag or stepper widget (class list: AiwaAvatar, AiwaButton, AiwaChip, AiwaIconButton, AiwaTextField, EmptyState, ErrorState, EyebrowLabel, GuestLockedView, Shimmer*, ScreenHeader, PageTitle, StickyBar, SettingsRow, InlineBanner, EndOfList, MetaDot, AiwaGlow, AiwaWordmark, SectionHeader, StarRating, StatusPill).
  - Fix: Add AiwaToggle({value, onChanged, tone}) and AiwaTag({label, tone}) with the kit sizes before building PROV-26..PROV-47.

#### Cross-cutting `-`
- **[MINOR · tokens] Hard-coded rgba literals in the prototype are mapped to theme tokens in Flutter** `PROV-C6`
  - Prototype: provider-screens.jsx:45,56,498 and provider-extras.jsx:31 use literal rgba(231,186,182,.3/.4) and rgba(250,245,238,.12), identical in both palettes.
  - Flutter now: dashboard_page.dart:207-211,353 use AppColors.rose300 / AppColors.bone opacity, which change per gender (male #B5A898 vs the prototype's pink).
  - Fix: Keep the token approach (more consistent), but document it as an intentional deviation in the theme README. If exact parity is required, add `static const heroGlow = Color(0xFFE7BAB6);` to AppColors.
