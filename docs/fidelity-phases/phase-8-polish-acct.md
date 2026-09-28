# Polish backlog — acct (minor findings)

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · tokens] Header glow colour/geometry and name letter-spacing** `ACCT-01-F4`
  - Prototype: prototype.jsx:358 radial-gradient(circle at 70% 30%, rgba(231,186,182,.4), transparent 60%) over the whole header (literal #E7BAB6, not themed); name prototype.jsx:362 fontDisp 24 lh 1.1 with no letterSpacing
  - Flutter now: profile_page.dart:184-188 AiwaGlow(size: 260, color: AppColors.rose300 (male #B5A898 / female #E6BAB0), opacity: 0.4) at right:-60 top:-30; name profile_page.dart:211 AppTextStyles.h2.copyWith(fontSize: 24...) keeps h2 letterSpacing -0.26 (app_text_styles.dart:27)
  - Fix: Positioned(right: -40, top: -60, child: AiwaGlow(size: 320, color: const Color(0xFFE7BAB6), opacity: 0.4)) and add letterSpacing: 0 to the name style.

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · components] Language row is missing the chevron the prototype draws on every non-danger row** `ACCT-01-F5`
  - Prototype: prototype.jsx:349 { icon: 'globe', label: 'Language', value: 'English' } has no onTap (the row is inert in the prototype too); prototype.jsx:397 `{!r.danger && <Icon name="chevron-right" size={16} color={aiwa.ink3} />}` still renders the chevron on it
  - Flutter now: profile_page.dart:70-76 Language SettingsRow has no onTap; screen_chrome.dart:223 `if (!danger && onTap != null)` so no chevron is drawn
  - Fix: In screen_chrome.dart add `final bool? showChevron;` to SettingsRow and change line 223 to `if (!danger && (showChevron ?? onTap != null))`; pass `showChevron: true` on the Language row in profile_page.dart. Making the row open a language picker (AuthRemoteDataSource.updateLanguage -> PATCH ApiConstants.meLanguage) is optional and goes beyond the prototype.

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · states] Guest view is keyed on AuthAuthenticated, so a future profile update would flip signed-in users to the guest lock** `ACCT-01-F6`
  - Prototype: prototype.jsx:709-711: the guest view depends only on the isGuest flag; a signed-in user always sees ProfileScreen
  - Flutter now: profile_page.dart:26-27 `final user = state is AuthAuthenticated ? state.user : null; if (user == null) return GuestLockedView`. auth_bloc.dart:132-144 _onUpdateProfile emits AuthLoading and then AuthProfileUpdated (never AuthAuthenticated). Nothing dispatches AuthUpdateProfileEvent yet (only declared at auth_event.dart:62), so this is latent today. It becomes visible as soon as the Personal info page (ACCT-13) saves.
  - Fix: auth_bloc.dart _onUpdateProfile: drop `emit(AuthLoading())` and emit `AuthAuthenticated(user)` on success (or AuthProfileUpdated followed by AuthAuthenticated). profile_page.dart: `BlocBuilder<AuthBloc, AuthState>(buildWhen: (_, s) => s is AuthAuthenticated || s is AuthUnauthenticated, ...)` so transient states never rebuild into the guest view.

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · interaction] Tab-switch transition missing** `ACCT-01-F7`
  - Prototype: prototype.jsx:563-570 tab change sets direction 'back', which gives animation 'aiwa-fade-in 320ms cubic-bezier(.32,.72,0,1)' (prototype.jsx:729-731; prototype.html:20-23 scale(.98 -> 1))
  - Flutter now: app_router.dart:173-177 NoTransitionPage(child: ProfilePage())
  - Fix: Use CustomTransitionPage(transitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, c) => ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: c)) for the shell tabs.

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · rtl] Arabic language value rendered without the Arabic font or locale support** `ACCT-01-F8`
  - Prototype: tokens/colors_and_type.css:96-101 --font-body falls back to 'IBM Plex Sans Arabic'; --font-display falls back to 'Markazi Text'; css:277-282 swaps fonts under [dir=rtl]/[lang=ar]
  - Flutter now: profile_page.dart:73-75 shows 'العربية' in AppTextStyles.meta (Plus Jakarta Sans only, app_text_styles.dart:151-169, no fontFamilyFallback). app.dart:81-82 hard-codes locale: Locale('en') with no localizationsDelegates, although flutter_localizations is in pubspec.yaml
  - Fix: In app_text_styles.dart _sans/_serif add fontFamilyFallback: [GoogleFonts.ibmPlexSansArabic().fontFamily!] / [GoogleFonts.markaziText().fontFamily!]. In app.dart add localizationsDelegates: GlobalMaterialLocalizations.delegates and drive locale from user.preferredLanguage.

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · layout] Row value and chevron sit 8px / 6px apart instead of the 14px row gap** `ACCT-01-V1`
  - Prototype: prototype.jsx:384 row `display: 'flex', alignItems: 'center', gap: 14`; the 14px gap applies label -> value and value -> chevron (prototype.jsx:395-397)
  - Flutter now: screen_chrome.dart:218-226 value wrapped in `EdgeInsets.only(left: 8)` and chevron preceded by `SizedBox(width: 6)`, e.g. the Language 'English' row (profile_page.dart:70-76)
  - Fix: In SettingsRow (non-boxed) use `padding: const EdgeInsets.only(left: 14)` for the value and `const SizedBox(width: 14)` before the chevron; use 13 for the boxed variant (states.jsx:442).

#### Profile tab (signed-in customer) `ACCT-01`
- **[MINOR · layout] Profile hero content sits 4px lower than the same 68px header on Home** `ACCT-01-V2`
  - Prototype: prototype.jsx:357 header padding '68px 22px 22px', the same 68px top as the Home header (screens.jsx:71 '68px 22px 16px')
  - Flutter now: profile_page.dart:192 `MediaQuery.paddingOf(context).top + 26`, while home_page.dart:140 maps the same 68px to `top + 22`
  - Fix: profile_page.dart:192 -> `MediaQuery.paddingOf(context).top + 22`.

#### Profile tab - guest-locked state `ACCT-02`
- **[MINOR · content] Guest profile title/body copy differs** `ACCT-02-F1`
  - Prototype: prototype.jsx:710 title="Your profile" body="Sign in to manage your account, addresses, and notifications."
  - Flutter now: profile_page.dart:33-35 title: 'Make AIWA yours', body: 'Sign in to manage your details, notifications and bookings.'
  - Fix: GuestLockedView(title: 'Your profile', body: 'Sign in to manage your account, addresses, and notifications.', icon: Icons.person_outline_rounded)

#### Profile tab - guest-locked state `ACCT-02`
- **[MINOR · tokens] Guest title carries h2 negative letter-spacing (tokens dimension should be 'deviates')** `ACCT-02-V1`
  - Prototype: customer-extras-2.jsx:19 h2 fontDisp 24, lineHeight 1.1, no letterSpacing
  - Flutter now: guest_locked_view.dart:45 `AppTextStyles.h2.copyWith(fontSize: 24, height: 1.1)` keeps h2 letterSpacing -0.26 (app_text_styles.dart:27)
  - Fix: guest_locked_view.dart:45 -> `AppTextStyles.h2.copyWith(fontSize: 24, height: 1.1, letterSpacing: 0)`.

#### Sign-out confirm sheet `ACCT-03`
- **[MINOR · tokens] Danger tone used instead of neutral; sheet shadow/scrim/padding differ** `ACCT-03-F2`
  - Prototype: prototype.jsx:757 tone="neutral", which resolves to plum100 bg / plum700 fg / 'primary' confirm (states.jsx:229-231); sheet padding bottom 34, shadow '0 -12px 32px rgba(42,19,32,.2)', scrim literal rgba(42,19,32,.48) (states.jsx:234-240)
  - Flutter now: profile_page.dart:101-108 omits danger:, so the default danger: true (confirm_sheet.dart:19) gives danger100/danger700 + AiwaButtonVariant.danger (confirm_sheet.dart:30-31, 121-123). Hex happens to be identical today (male danger700 = plum700 = #2E2A26, female #6B3A3A). Padding bottom 24 + safe inset (confirm_sheet.dart:40); shadow AppColors.plum700 @ .14 (app_theme.dart:44-50); barrier AppColors.plum900 @ .48 (confirm_sheet.dart:27; male #2E2A26)
  - Fix: Pass danger: false. In AppTheme.sheetDecoration use BoxShadow(color: const Color(0x332A1320), blurRadius: 32, offset: Offset(0, -12)); barrierColor: const Color(0x7A2A1320); bottom padding 34 + safe inset minus the device home-indicator overlap.

#### Notifications inbox (customer) `ACCT-20`
- **[MINOR · states] Header '· N new' counts only the first page** `ACCT-20-F4`
  - Prototype: customer-extras.jsx:112 unreadCount = items.filter(n => n.unread).length over the full list
  - Flutter now: notification_bloc.dart:54 unreadCount: paged.content.where((n) => !n.read).length (page 0, size 20), which overwrites the server count that Home loaded via NotificationGetUnreadCountEvent (home_page.dart:57)
  - Fix: In _onLoad, also call getUnreadCount() and use its value; keep decrementing locally on mark-read.

#### Notifications inbox (customer) `ACCT-20`
- **[MINOR · content] Status notifications use a calendar glyph instead of navigation / check-circle** `ACCT-20-F5`
  - Prototype: customer-extras.jsx:101-102 'Nadia is on the way' icon 'navigation'; 'Booking accepted' icon 'check-circle'
  - Flutter now: notifications_page.dart:175-177 any type containing BOOKING/STATUS -> Icons.event_available_outlined
  - Fix: Map finer-grained types, e.g. if (t.contains('ON_THE_WAY')) return Icons.navigation_outlined; if (t.contains('ACCEPT') || t.contains('CONFIRM')) return Icons.check_circle_outline_rounded; else Icons.event_available_outlined. Backend type names are not visible.

#### Notifications inbox (customer) `ACCT-20`
- **[MINOR · tokens] Title line-heights / letter-spacing slightly off** `ACCT-20-F6`
  - Prototype: customer-extras.jsx:122 h1 fontDisp 24 lineHeight 1.05, no letterSpacing; customer-extras.jsx:158 row title lineHeight 1.2
  - Flutter now: screen_chrome.dart:58-61 AppTextStyles.h3.copyWith(fontSize: 24, height: 1.1), inheriting h3 letterSpacing -0.22 (app_text_styles.dart:34); notifications_page.dart:248 row title height: 1.25
  - Fix: Add a titleHeight param to ScreenHeader (1.05 here) with letterSpacing: 0; set the row title to height: 1.2.

#### Notifications inbox (customer) `ACCT-20`
- **[MINOR · layout] Unread dot sits 8px from the text column instead of 12px** `ACCT-20-F7`
  - Prototype: customer-extras.jsx:143 row `gap: 12` applies between the text column and the dot (customer-extras.jsx:163)
  - Flutter now: notifications_page.dart:272 margin: const EdgeInsets.only(left: 8, top: 14)
  - Fix: margin: const EdgeInsets.only(left: 12, top: 14)

#### Notifications inbox (customer) `ACCT-20`
- **[MINOR · layout] Title/time row is top-aligned instead of baseline-aligned** `ACCT-20-V1`
  - Prototype: customer-extras.jsx:157 title/time row `display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 6`
  - Flutter now: notifications_page.dart:237-238 `Row(crossAxisAlignment: CrossAxisAlignment.start, ...)`, so the 11px time label is top-aligned with the 14px title instead of sharing its baseline
  - Fix: notifications_page.dart:238 -> `crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,`

#### Cross-cutting `-`
- **[MINOR · components] SettingsRow boxed variant diverges from the kit's SettingsRow** `ACCT-C03`
  - Prototype: states.jsx:438-461 SettingsRow: boxed paper radius 14, padding 13x14, gap 13; icon tile 36 radius 11 with plum/gold/danger tone; label 14/600; sub 11.5 ink3; value 12.5 ink3; `right` slot; chevron-right 17 ink4
  - Flutter now: screen_chrome.dart:155-258 SettingsRow: tile radius 10, gap 14, label AppTextStyles.body w500 15 (lines 201-205), value AppTextStyles.meta 13 (221), chevron 16 ink3 (225), no tone/right params. The 15/500 styling matches only the Profile inline rows (prototype.jsx:395)
  - Fix: When boxed is true use label 14 w600, tile radius 11, gap 13, value 12.5, chevron 17 AppColors.ink4. Add `Widget? right` and `bool gold` params (gold100/gold700 tile). Needed by Safety & policies, Personal info and Trusted contacts.

#### Cross-cutting `-`
- **[MINOR · tokens] Serif headings inherit negative letter-spacing where the kit has none** `ACCT-C05`
  - Prototype: ScreenHeader h2 (states.jsx:419), EmptyState h3 (states.jsx:97) and the Profile name (prototype.jsx:362) set no letterSpacing; only SectionHeader uses -0.01em (components.jsx:196)
  - Flutter now: AppTextStyles.h2 letterSpacing -0.26 (app_text_styles.dart:27) and h3 -0.22 (app_text_styles.dart:34) carry into ScreenHeader (screen_chrome.dart:58), EmptyState (empty_state.dart:69), ConfirmSheet (confirm_sheet.dart:75) and the Profile name (profile_page.dart:211)
  - Fix: Override letterSpacing: 0 in ScreenHeader, EmptyState/ErrorState, GuestLockedView and the Profile header. Keep -0.01em only for SectionHeader.

#### Cross-cutting `-`
- **[MINOR · interaction] Pushed routes don't use the prototype slide-in transition** `ACCT-C06`
  - Prototype: prototype.jsx:724-731 pushed screens animate 'aiwa-slide-in 320ms cubic-bezier(.32,.72,0,1)' (prototype.html:16-19 translateX(8%) -> 0)
  - Flutter now: app_router.dart:180-226 use plain GoRoute builder, so platform default MaterialPage transitions. AppTheme.easeSoft / dur3 (app_theme.dart:31-33) are defined but not used for routes
  - Fix: Add a helper `Page<void> aiwaPage(Widget child) => CustomTransitionPage(child: child, transitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, c) => SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: c));` and use pageBuilder for /notifications and all new account routes.
