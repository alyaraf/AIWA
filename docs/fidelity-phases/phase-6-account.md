# Customer account, notifications, support, permission-denied screens

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.

## Targeted findings

- **[MAJOR · components] No top Toast component; SnackBars are used instead** `ACCT-C01`
  - Prototype: prototype.jsx:20-39 Toast: absolute top:56, left/right 16, bg rgba(42,19,32,.96), radius 14, padding 12x16, 26px success500 circle + white check 15, text 13/500 bone, aiwa-toast 320ms slide-down, auto-dismiss 2800ms. Used for every account toast (prototype.jsx:676-678, 715, 753)
  - Flutter now: app_theme.dart:185-193 snackBarTheme: plum900 @ .96, bodySm 14 w500 bone, floating at the bottom, radius 14, no check badge; used ad hoc (review_page.dart:91-92, my_bookings_page.dart:129)
  - Fix: Add lib/shared/widgets/aiwa_toast.dart with showAiwaToast(context, message) as specified in ACCT-05 and replace ScaffoldMessenger.showSnackBar calls with it.

- **[MAJOR · tokens] Arabic typography and localization not wired** `ACCT-C02`
  - Prototype: tokens/colors_and_type.css:96-101 font stacks include 'Markazi Text' (display) and 'IBM Plex Sans Arabic' (body); css:277-285 swaps to the Arabic families under [dir=rtl]/[lang=ar]; the prototype shows Arabic copy ('العربية' at account-screens.jsx:61 and customer-extras.jsx:300)
  - Flutter now: app_text_styles.dart:131-189 define only DM Serif Display / Plus Jakarta Sans / JetBrains Mono with no fontFamilyFallback; app.dart:81-82 fixes locale: const Locale('en') with supportedLocales but no localizationsDelegates, although flutter_localizations is in pubspec.yaml:12
  - Fix: In _serif/_sans (app_text_styles.dart) add fontFamilyFallback: [GoogleFonts.markaziText().fontFamily!] / [GoogleFonts.ibmPlexSansArabic().fontFamily!]. In app.dart add localizationsDelegates: GlobalMaterialLocalizations.delegates and set locale from AuthAuthenticated.user.preferredLanguage.

- **[MINOR · components] SettingsRow boxed variant diverges from the kit's SettingsRow** `ACCT-C03`
  - Prototype: states.jsx:438-461 SettingsRow: boxed paper radius 14, padding 13x14, gap 13; icon tile 36 radius 11 with plum/gold/danger tone; label 14/600; sub 11.5 ink3; value 12.5 ink3; `right` slot; chevron-right 17 ink4
  - Flutter now: screen_chrome.dart:155-258 SettingsRow: tile radius 10, gap 14, label AppTextStyles.body w500 15 (lines 201-205), value AppTextStyles.meta 13 (221), chevron 16 ink3 (225), no tone/right params. The 15/500 styling matches only the Profile inline rows (prototype.jsx:395)
  - Fix: When boxed is true use label 14 w600, tile radius 11, gap 13, value 12.5, chevron 17 AppColors.ink4. Add `Widget? right` and `bool gold` params (gold100/gold700 tile). Needed by Safety & policies, Personal info and Trusted contacts.

- **[MAJOR · components] No shared Toggle widget** `ACCT-C04`
  - Prototype: states.jsx:209-224 Toggle: 42x24 pill, background plum700 on / divider off (warn500 for tone warn), 18px white knob at left 21/3 with shadow 0 1px 3px rgba(42,19,32,.25), 200ms easeSoft. Used by the address Default toggle (account-screens.jsx:190); Notification preferences uses an inline 40x22 variant (flow-additions-v3.jsx:100-104)
  - Flutter now: No toggle in lib/shared/widgets (14 files: aiwa_avatar, aiwa_button, aiwa_chip, aiwa_icon_button, aiwa_text_field, confirm_sheet, empty_state, eyebrow_label, guest_locked_view, loading_shimmer, screen_chrome, section_header, star_rating, status_pill); no Switch theme in app_theme.dart
  - Fix: Add lib/shared/widgets/aiwa_toggle.dart: GestureDetector -> AnimatedContainer(width: 42, height: 24, borderRadius 999, color: value ? AppColors.plum700 : AppColors.divider) with an AnimatedPositioned 18px knob (left: value ? 21 : 3, top 3, BoxShadow(color: Color(0x402A1320), blurRadius: 3, offset: Offset(0,1))), duration AppTheme.dur2, curve AppTheme.easeSoft.

- **[MINOR · tokens] Serif headings inherit negative letter-spacing where the kit has none** `ACCT-C05`
  - Prototype: ScreenHeader h2 (states.jsx:419), EmptyState h3 (states.jsx:97) and the Profile name (prototype.jsx:362) set no letterSpacing; only SectionHeader uses -0.01em (components.jsx:196)
  - Flutter now: AppTextStyles.h2 letterSpacing -0.26 (app_text_styles.dart:27) and h3 -0.22 (app_text_styles.dart:34) carry into ScreenHeader (screen_chrome.dart:58), EmptyState (empty_state.dart:69), ConfirmSheet (confirm_sheet.dart:75) and the Profile name (profile_page.dart:211)
  - Fix: Override letterSpacing: 0 in ScreenHeader, EmptyState/ErrorState, GuestLockedView and the Profile header. Keep -0.01em only for SectionHeader.

- **[MINOR · interaction] Pushed routes don't use the prototype slide-in transition** `ACCT-C06`
  - Prototype: prototype.jsx:724-731 pushed screens animate 'aiwa-slide-in 320ms cubic-bezier(.32,.72,0,1)' (prototype.html:16-19 translateX(8%) -> 0)
  - Flutter now: app_router.dart:180-226 use plain GoRoute builder, so platform default MaterialPage transitions. AppTheme.easeSoft / dur3 (app_theme.dart:31-33) are defined but not used for routes
  - Fix: Add a helper `Page<void> aiwaPage(Widget child) => CustomTransitionPage(child: child, transitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, c) => SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: c));` and use pageBuilder for /notifications and all new account routes.


## Entries

### Profile tab (signed-in customer) — `ACCT-01` (screen, deviates)
- How the user reaches it: Splash -> sign in / sign up -> Home -> bottom tab bar 'Profile'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:342-402 (ProfileScreen); case 'profile' prototype.jsx:709-711
- Flutter files: Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/core/router/app_router.dart, Android/aiwa_app/lib/features/shell/shell_page.dart
- Key elements: Header gradient linear-gradient(160deg, plum700, plum900) (male #2E2A26 / female #6B3A3A) + radial glow rgba(231,186,182,.4) at 70% 30%; Avatar 'Layla' palette rose 64px; name 'Layla Hassan' DM Serif 24 lh1.1 bone; phone '+20 100 555 8821' 13px rose300; 3 stat tiles (12 Bookings / 3 Favorites / 5 Reviews): bg rgba(250,245,238,.12), radius 14, value DM Serif 22, label 11/600 uppercase 0.08em rose300; 10 rows (36px icon tile radius 10 plum100/plum700, label 15/500 ink, value 13 ink3, chevron-right 16 ink3 on non-danger rows): Personal info, Saved addresses, Trusted contacts '1 saved', Notifications, Notification preferences, Language 'English', Safety & policies, WhatsApp support, Sign out (danger), Delete account (danger); Row dividers 1px divider except last; list padding '20px 22px 0'; page paddingBottom 100
- Findings:
  - **[CRITICAL · interaction] 7 of 10 Profile rows missing; their destinations are unreachable** `ACCT-01-F1`
    - Prototype: prototype.jsx:343-354 rows: Personal info (user) -> push('edit-profile'), Saved addresses (map-pin) -> push('addresses'), Trusted contacts (user-round-plus, value '1 saved') -> push('trusted-contacts'), Notifications (bell), Notification preferences (bell-ring) -> push('notif-prefs'), Language (globe, 'English'), Safety & policies (shield-check) -> push('safety-policies'), WhatsApp support (message-circle) -> push('support'), Sign out, Delete account (trash-2) -> setShowDeleteAccount(true); wiring prototype.jsx:711
    - Flutter now: profile_page.dart:56-89 renders only Notifications, App palette, Language, Email (conditional) and Sign out. AppRoutes (app_router.dart:29-55) has no addresses / edit-profile / trusted-contacts / notif-prefs / safety-policies / support routes
    - Fix: In profile_page.dart replace the Column children with the prototype order and add the routes (see ACCT-04/06/13/15/16/21/22 build notes):
  SettingsRow(icon: Icons.person_outline_rounded, label: 'Personal info', onTap: () => context.push(AppRoutes.editProfile)),
  SettingsRow(icon: Icons.place_outlined, label: 'Saved addresses', onTap: () => context.push(AppRoutes.addresses)),
  SettingsRow(icon: Icons.person_add_alt_outlined, label: 'Trusted contacts', value: '${contacts.length} saved', onTap: () => context.push(AppRoutes.trustedContacts)),
  SettingsRow(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push(AppRoutes.notifications)),
  SettingsRow(icon: Icons.notifications_active_outlined, label: 'Notification preferences', onTap: () => context.push(AppRoutes.notifPrefs)),
  SettingsRow(icon: Icons.language_rounded, label: 'Language', value: lang, onTap: _pickLanguage),
  SettingsRow(icon: Icons.verified_user_outlined, label: 'Safety & policies', onTap: () => context.push(AppRoutes.safetyPolicies)),
  SettingsRow(icon: Icons.chat_bubble_outline_rounded, label: 'WhatsApp support', onTap: () => context.push(AppRoutes.support)),
  SettingsRow(icon: Icons.logout_rounded, label: 'Sign out', danger: true, onTap: () => _signOut(context)),
  SettingsRow(icon: Icons.delete_outline_rounded, label: 'Delete account', danger: true, showDivider: false, onTap: () => _deleteAccount(context)),
  - **[MAJOR · components] Header stats tiles (Bookings / Favorites / Reviews) missing** `ACCT-01-F2`
    - Prototype: prototype.jsx:366-379: flex row gap 10 marginTop 18; each tile flex:1, background 'rgba(250,245,238,.12)', borderRadius 14, padding '10px 14px', backdropFilter blur(8px); value fontDisp 22 lh 1; label 11px/600, letterSpacing 0.08em, uppercase, color rose300 (male #B5A898 / female #E6BAB0)
    - Flutter now: profile_page.dart:196-230: the _Header Row only has AiwaAvatar + name + contact; no stats
    - Fix: Under the Row in _Header add:
  const SizedBox(height: 18),
  Row(children: [for (final (i, s) in [(bookings, 'Bookings'), (saved, 'Favorites'), (reviews, 'Reviews')].indexed) Expanded(child: Container(margin: EdgeInsets.only(left: i == 0 ? 0 : 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0x1FFAF5EE), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${s.$1}', style: AppTextStyles.h3.copyWith(fontSize: 22, height: 1, letterSpacing: 0, color: AppColors.bone)), const SizedBox(height: 2), Text(s.$2.toUpperCase(), style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.88, color: AppColors.rose300))])))]),
  The counts come from MyBookings (GET /bookings/my), saved (GET /users/me/saved) and a review count, which needs a backend field.
  - **[MAJOR · layout] Row order/set differs; Flutter-only 'App palette' and 'Email' rows** `ACCT-01-F3`
    - Prototype: prototype.jsx:343-354 fixed order: Personal info, Saved addresses, Trusted contacts, Notifications, Notification preferences, Language, Safety & policies, WhatsApp support, Sign out, Delete account. The theme choice lives inside Personal info as the 'Theme' Mauve/Charcoal picker (account-screens.jsx:40-59); email is a field there too (account-screens.jsx:38)
    - Flutter now: profile_page.dart:61-69 'App palette' row (value 'Mauve'/'Charcoal', opens the _pickPalette sheet at 114-169); profile_page.dart:77-82 read-only 'Email' row
    - Fix: Remove both rows from profile_page.dart. Move the palette picker into the new Personal info page as the 2-column 'Theme' selector, reusing _PaletteOption, and show email as an editable AiwaTextField there.

### Profile tab - guest-locked state — `ACCT-02` (state, deviates)
- How the user reaches it: Splash -> Browse as guest -> bottom tab 'Profile'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:709-710; customer-extras-2.jsx:11-25 (GuestLockedScreen)
- Flutter files: Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart, Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart
- Key elements: 64px plum100 circle with 'user' icon 28 plum700; Eyebrow 'Browsing as guest'; h2 'Your profile' DM Serif 24 lh1.1 plum900; Body 'Sign in to manage your account, addresses, and notifications.' 13.5 ink2 maxWidth 280; Primary lg full 'Sign in or create account' -> push('auth-gate')
- Findings:
  - **[CRITICAL · interaction] CTA goes to Role choice instead of the Auth gate** `ACCT-02-F2`
    - Prototype: prototype.jsx:710 onSignIn={() => push('auth-gate')}, which is AuthGateScreen 'Sign in to book.' with 'Create account' / 'I already have an account' (customer-extras-2.jsx:27-54)
    - Flutter now: guest_locked_view.dart:65 onPressed: () => context.push(AppRoutes.roleChoice)
    - Fix: guest_locked_view.dart: onPressed: () => context.push(AppRoutes.authGate) (the route exists at app_router.dart:206). Or add an onSignIn parameter so each tab can pass its own target.

### Sign-out confirm sheet — `ACCT-03` (sheet, deviates)
- How the user reaches it: Profile tab -> 'Sign out' row
- Prototype source: ui_kits/aiwa-app/prototype.jsx:756-758; states.jsx:227-257 (ConfirmSheet)
- Flutter files: Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart, Android/aiwa_app/lib/shared/widgets/confirm_sheet.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: Scrim rgba(42,19,32,.48); bone sheet radius 24, padding '18px 22px 34px', shadow 0 -12px 32px rgba(42,19,32,.2), 40x4 handle; tone='neutral': 46px plum100 circle, 'log-out' icon plum700; Eyebrow 'Your account' plum700; title 'Sign out of AIWA?' DM Serif 23 lh1.12; Body 'Your bookings, saved providers and addresses all stay safe. You'll need a code to sign back in.'; Cancel (secondary lg) + 'Sign out' (primary lg) -> setIsGuest(false); reset('splash')
- Findings:
  - **[MAJOR · content] Sign-out body/eyebrow copy changes the message** `ACCT-03-F1`
    - Prototype: prototype.jsx:757-758 eyebrow="Your account" body="Your bookings, saved providers and addresses all stay safe. You'll need a code to sign back in."
    - Flutter now: profile_page.dart:103 eyebrow: 'Sign out'; profile_page.dart:105 body: "You'll need your phone or email and password to sign back in." (drops the data-safety reassurance and says password instead of code)
    - Fix: showConfirmSheet(context, eyebrow: 'Your account', title: 'Sign out of AIWA?', body: "Your bookings, saved providers and addresses all stay safe. You'll need a code to sign back in.", confirmLabel: 'Sign out', icon: Icons.logout_rounded, danger: false)

### Delete account sheet (type DELETE to confirm) — `ACCT-04` (sheet, missing)
- How the user reaches it: Profile tab -> 'Delete account' row
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:217-248; mounted prototype.jsx:751-755
- Flutter files: none yet
- Key elements: Scrim rgba(42,19,32,.5); bone sheet radius 24, padding '18px 22px 36px', shadow 0 -12px 32px rgba(0,0,0,.18), handle; Eyebrow "This can't be undone" danger700; h2 'Delete your account?' DM Serif 22; Body 'Your data will be anonymized and any active bookings cancelled. Type DELETE to confirm.'; Input placeholder 'DELETE' JetBrains Mono 14, radius 14, 1.5px divider border, paper bg; Cancel (secondary) + 'Delete account' (danger, opacity .5 until text === 'DELETE'); Confirm -> toast 'Account deleted. Sorry to see you go.' -> reset('splash')
- To build: Add showDeleteAccountSheet(context) in lib/shared/widgets/confirm_sheet.dart, or add a `requiredPhrase` parameter to showConfirmSheet. Reuse AppTheme.sheetDecoration and a TextField styled with AppTextStyles.mono.copyWith(fontSize: 14) and AppTheme.inputBorder(AppColors.divider). Wrap the confirm AiwaButton(variant: danger) in ValueListenableBuilder<TextEditingValue> on the controller: onPressed: v.text == 'DELETE' ? () => Navigator.pop(ctx, true) : null (AiwaButton already dims to .45 when onPressed is null, aiwa_button.dart:112; the prototype uses .5). Backend: no delete endpoint exists in api_constants.dart:13-16, so add DELETE /auth/me (or /users/me) to AuthRemoteDataSource plus an AuthDeleteAccountEvent in auth_bloc.dart that calls it, secureStorage.clearAll() and emits AuthUnauthenticated. Then context.go(AppRoutes.splash) and show the ACCT-05 toast. Add the danger row to profile_page.dart (see ACCT-01-F1).

### Toast: 'Account deleted. Sorry to see you go.' — `ACCT-05` (toast, missing)
- How the user reaches it: Profile -> Delete account -> type DELETE -> 'Delete account'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:751-754; Toast component prototype.jsx:20-39
- Flutter files: none yet
- Key elements: Top overlay at top:56, left/right 16, bg rgba(42,19,32,.96), radius 14, padding 12x16, shadow 0 12px 32px rgba(74,31,56,.3), blur 8; 26px success500 circle with white check 15; Message 13px/500 bone (Plus Jakarta Sans); Enters with aiwa-toast 320ms (opacity 0 -> 1, translateY -10 -> 0); auto-dismiss 2800ms
- To build: No top-toast component exists. Flutter only uses bottom SnackBars (app_theme.dart:185-193, e.g. review_page.dart:91-92). Build lib/shared/widgets/aiwa_toast.dart with showAiwaToast(BuildContext, String) using an OverlayEntry on rootNavigatorKey's overlay: Positioned(top: MediaQuery.paddingOf(ctx).top + 12, left: 16, right: 16) Container(color: const Color(0xF52A1320), radius 14, padding EdgeInsets.symmetric(horizontal: 16, vertical: 12), boxShadow Color(0x4D4A1F38) blur 32 offset (0,12)) Row[26px circle AppColors.success500 + Icon(Icons.check, size 15, white), SizedBox(10), Text(msg, AppTextStyles.meta 13 w500 AppColors.bone)]. Use a SlideTransition/FadeTransition with AppTheme.dur3 + AppTheme.easeSoft and remove it after 2800ms. Call it after the ACCT-04 confirm, before context.go(AppRoutes.splash) (the overlay survives because it sits on the root navigator).

### Saved addresses list — `ACCT-06` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'Saved addresses'
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:179-215 (AddressesScreen, SAVED_ADDRESSES); prototype.jsx:674
- Flutter files: none yet
- Key elements: Header padding '60px 22px 8px': IconBtn arrow-left, Eyebrow 'Account', h2 'Saved addresses' DM Serif 22 lh1.1; Address cards: paper, radius 16, 1px divider, padding 14, gap 14; 40px plum100 tile radius 12 with house/briefcase icon 18; label 14/600 ink; address 12.5 ink3; pencil IconBtn 34 -> edit; Seed: Home '14 Road 9, Maadi, Cairo'; Work 'Smart Village, 6th of October'; Dashed 'Add new address' button (1.5px dashed divider, radius 16, plus 16, plum700 14/600) -> new address form
- To build: Create lib/features/addresses/ (data: AddressRemoteDataSource + AddressModel; domain: AddressEntity{id,label,street,building,floor,apartment,landmark,notes,isDefault,lat,lng}; presentation: AddressBloc + addresses_page.dart). Add AppRoutes.addresses = '/addresses' in app_router.dart (root-level GoRoute like /notifications). UI reuses ScreenHeader(eyebrow: 'Account', title: 'Saved addresses', onBack: context.pop), AiwaIconButton(icon: Icons.edit_outlined, size: 34) and a Container with AppColors.paper, radius 16, Border.all(AppColors.divider). The dashed add button needs a dashed border (CustomPainter; there's no dashed helper in shared/widgets). Backend: no address endpoints in api_constants.dart, so GET/POST/PUT/DELETE /users/me/addresses is needed. The prototype designs no empty or loading state here; use EmptyState(compact: true) and SkeletonList as fallbacks. booking_page.dart presumably also needs this list to pre-select the default address (not verified).

### New address form (add mode) — `ACCT-07` (sub-screen, missing)
- How the user reaches it: Profile -> Saved addresses -> 'Add new address'
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:116-215 (AddressFormScreen, existing=null); prototype.jsx:674-677
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Saved addresses', title 'New address'; Map placeholder 132px radius 18, gradient 150deg plum100 -> cream -> gold100, 26px grid at 50% opacity, 38px plum700 pin with shadow, 'Drop pin' pill (crosshair, rgba(255,255,255,.94)); Label segmented control Home/Work/Other (house/briefcase/map-pin): selected plum700 bg + white text; unselected paper + 1.5px divider; Street & area (signpost, placeholder 'e.g. Road 9, Maadi'; error 'Add the street and area so your provider can find you.' when < 4 chars); Grid 1.4fr/1fr/1fr: Building (placeholder '14'; error 'Building number or name is required.'), Floor optional '3', Apt optional '7'; Nearest landmark optional (landmark icon, 'e.g. opposite Sakia', hint 'Helps providers find you faster on the first visit.'); Notes for the provider optional, multiline, maxLength 140 with mono counter, placeholder 'Gate code, parking, which bell to ring…'; Default address row: star tile + 'Default address' / 'Pre-selected on every home booking' + Toggle; StickyBar: Cancel (secondary lg) + 'Add address' (primary lg, opacity .45 until valid); Validation errors only after blur (ValidatedInput touched)
- To build: Build address_form_page.dart(existing: AddressEntity?) under lib/features/addresses/presentation/pages with routes '/addresses/new' and '/addresses/:id/edit'. Reuse AiwaTextField (it already has label/icon/placeholder/error/hint/optional/maxLength/showCounter, aiwa_text_field.dart:9-28) for every field, StickyBar (screen_chrome.dart:132) with Row[Expanded(AiwaButton secondary lg 'Cancel'), SizedBox(10), Expanded(AiwaButton primary lg 'Add address', onPressed: valid ? _save : null)]. Build the map placeholder with a Container gradient (AppColors.plum100, cream, gold100) + a CustomPaint grid. The pin picker can use geolocator (already in pubspec) for 'Drop pin'; no map SDK is installed. Needs the shared AiwaToggle (see ACCT-C04). On save: AddressBloc add, then showAiwaToast('Address added.') (ACCT-10), then context.pop().

### Edit address form (edit mode) — `ACCT-08` (sub-screen, missing)
- How the user reaches it: Profile -> Saved addresses -> pencil icon on an address
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:121-215 (existing != null); prototype.jsx:674-677
- Flutter files: none yet
- Key elements: ScreenHeader title 'Edit address' (eyebrow 'Saved addresses'); All fields pre-filled from the existing address; Outlined danger button 'Delete this address' (trash-2 15, 1.5px danger100 border, danger700 14/600, radius 14, padding 13) -> delete ConfirmSheet; StickyBar primary label 'Save address'
- To build: Same AddressFormPage as ACCT-07 in edit mode: initialise the TextEditingControllers from `existing`, switch the header title and primary label ('Save address'), and show the delete button only when existing != null. The button is a GestureDetector/OutlinedButton with side: BorderSide(color: AppColors.danger100, width: 1.5), foreground AppColors.danger700, Icons.delete_outline_rounded 15. Save -> PUT /users/me/addresses/{id} -> showAiwaToast('Address updated.') (ACCT-11) -> pop.

### Delete address confirm sheet — `ACCT-09` (sheet, missing)
- How the user reaches it: Profile -> Saved addresses -> pencil -> 'Delete this address'
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:210-212
- Flutter files: none yet
- Key elements: ConfirmSheet tone danger, icon 'trash-2'; Eyebrow 'Remove address'; title 'Delete "<label>"?'; Body 'Bookings already made to this address keep their details. You can add it again any time.'; Cancel + 'Delete' (danger) -> onDelete -> toast 'Address deleted.' + pop
- To build: Reuse showConfirmSheet (confirm_sheet.dart:12) directly: final ok = await showConfirmSheet(context, eyebrow: 'Remove address', title: 'Delete "$label"?', body: 'Bookings already made to this address keep their details. You can add it again any time.', confirmLabel: 'Delete', icon: Icons.delete_outline_rounded); if (ok) { bloc.add(AddressDeleteEvent(id)); showAiwaToast(context, 'Address deleted.'); context.pop(); }. Needs DELETE /users/me/addresses/{id}.

### Toast: 'Address added.' — `ACCT-10` (toast, missing)
- How the user reaches it: Profile -> Saved addresses -> Add new address -> valid form -> 'Add address'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:676 (editAddress == null); Toast prototype.jsx:20-39
- Flutter files: none yet
- Key elements: Top toast (see ACCT-05) with message 'Address added.'; Screen pops back to Saved addresses
- To build: Depends on the shared showAiwaToast from ACCT-05 and the form from ACCT-07. Call showAiwaToast(context, 'Address added.') after a successful POST, then context.pop().

### Toast: 'Address updated.' — `ACCT-11` (toast, missing)
- How the user reaches it: Profile -> Saved addresses -> pencil -> 'Save address'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:676 (editAddress != null)
- Flutter files: none yet
- Key elements: Top toast with message 'Address updated.'; Pops back to Saved addresses
- To build: Uses showAiwaToast (ACCT-05) after the PUT succeeds in AddressFormPage edit mode (ACCT-08).

### Toast: 'Address deleted.' — `ACCT-12` (toast, missing)
- How the user reaches it: Profile -> Saved addresses -> pencil -> Delete this address -> 'Delete'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:677
- Flutter files: none yet
- Key elements: Top toast with message 'Address deleted.'; Pops back to Saved addresses
- To build: Uses showAiwaToast (ACCT-05) after the ACCT-09 confirm and DELETE succeed.

### Personal info (edit profile) — `ACCT-13` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'Personal info'
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:7-73 (EditProfileScreen); prototype.jsx:678
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Account', title 'Personal info'; Avatar 68 rose + 'Change photo' (secondary sm, camera icon) + 'JPG or PNG · max 5 MB' 11.5 ink4; Full name (user icon, placeholder 'Your name', error 'Enter your full name.'); Mobile number (phone icon, hint 'Changing this sends a verification code to the new number.', error 'Enter a valid Egyptian mobile number.'); Email optional (mail icon, error 'That email doesn’t look right.'); 'Theme' 2-column picker: Mauve (swatches plum500 + rose300) / Charcoal (#3A3A3C + #8E8E93); selected plum100 bg + 1.5px plum700 border + check; SettingsRow 'Language' (globe) toggling English / العربية; StickyBar Cancel + 'Save changes' (disabled .45 until valid && dirty); label 'Saving…' for 550ms -> toast 'Profile updated.' + pop
- To build: No page exists, but the plumbing is partly there. AuthUpdateProfileEvent(fullName, email, profileImageUrl) (auth_event.dart:62-72) -> PATCH /auth/me (auth_remote_datasource.dart:131-150); updateLanguage -> PATCH /auth/me/language; image_picker is in pubspec for 'Change photo'; the phone change can reuse AuthSendOtpEvent/AuthVerifyOtpEvent + OtpPage. Build lib/features/profile/presentation/pages/edit_profile_page.dart with route '/profile/edit'. Use AiwaAvatar(size: 68, palette: rose, imageUrl), AiwaButton(variant: secondary, size: sm, icon: Icons.photo_camera_outlined, label: 'Change photo'), three AiwaTextFields with errors, the Theme grid reusing _PaletteOption from profile_page.dart:238-292 (move it to shared) with ThemeController.set, SettingsRow(boxed: true) for Language, and StickyBar with AiwaButton(loading: saving) (AiwaButton pulses instead of showing 'Saving…'; pass label 'Saving…' to match). Fix first: auth_bloc.dart:132-144 emits AuthProfileUpdated, which makes ProfilePage show the guest lock (ACCT-01-F6), so emit AuthAuthenticated(user) instead. On success call showAiwaToast('Profile updated.') (ACCT-14) and context.pop().

### Toast: 'Profile updated.' — `ACCT-14` (toast, missing)
- How the user reaches it: Profile -> Personal info -> edit a field -> 'Save changes'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:678
- Flutter files: none yet
- Key elements: Top toast with message 'Profile updated.'; Pops back to Profile
- To build: Uses showAiwaToast (ACCT-05). Fire it from a BlocListener<AuthBloc> in EditProfilePage when the update succeeds.

### Safety & policies — `ACCT-15` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'Safety & policies'
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:75-114 (POLICY_DOCS, SafetyPoliciesScreen); prototype.jsx:679
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Account', title 'Safety & policies'; InlineBanner success, circle-check: "You're up to date" / 'You accepted the current terms on 20 May 2026. We'll tell you if anything changes.'; 5 boxed SettingsRows with sub + chevron-down/up (accordion, one open at a time): Terms of service 'v1.1.0 · accepted 20 May 2026', Safety policy 'Home visits, ID checks, SOS', Cancellation policy 'Cutoffs, penalties, no-shows', Privacy policy 'What we store and for how long', Community conduct 'What we expect from everyone'; Expanded panel: cream bg radius 13, 12.5 ink2 lh1.6 text + ghost sm 'Download PDF' (download icon); SectionHeader 'Your safety tools'; gold-tone rows 'Trusted contacts' (sub 'Alerted if you press SOS', value '1 saved') and 'How SOS works' (siren, 'What happens when you press it')
- To build: Build lib/features/profile/presentation/pages/safety_policies_page.dart with route '/profile/policies'. Reuse ScreenHeader, InlineBanner(tone: BannerTone.success, icon: Icons.check_circle_outline_rounded) (screen_chrome.dart:263), SectionHeader(title: 'Your safety tools') and SettingsRow(boxed: true, sub: ...). SettingsRow needs a `right` widget slot (for the chevron up/down) and a gold tone (states.jsx:448-449). Its boxed label is currently 15/500, but the kit uses 14/600 (ACCT-C03). Accordion: keep a String? open in local state and AnimatedSize for the cream panel. Data: GET /terms/latest (ApiConstants.termsLatest, api_constants.dart:77) plus UserEntity.acceptedTermsVersion (user_entity.dart:14) for the banner/sub text. Open the PDF with url_launcher (already used in my_bookings_page.dart:115). The 'Trusted contacts' row should push the ACCT-16 route; 'How SOS works' has no target in the prototype.

### Trusted contacts (list) — `ACCT-16` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'Trusted contacts' (value '1 saved')
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:217-295 (TrustedContactsScreen, TRUSTED_SEED); prototype.jsx:680
- Flutter files: none yet
- Key elements: ScreenHeader eyebrow 'Safety', title 'Trusted contacts'; InlineBanner warn, siren: 'Alerted the moment you press SOS' / 'They receive your live location by SMS. Nothing is shared with them at any other time.'; Contact card: paper radius 16, padding 13; Avatar gold 42; name 14/600; phone JetBrains Mono 12 ink3 ('+20 100 221 4477'); Tag gold 'Sister'; trash IconBtn 34; Dashed 'Add another contact' button (plus, plum700 14/600, radius 15)
- To build: Build lib/features/trusted_contacts/ (entity {id,name,phone,relationship}, bloc, page) with route '/trusted-contacts'. Reuse ScreenHeader, InlineBanner(tone: BannerTone.warn, icon: Icons.emergency_share_outlined), AiwaAvatar(palette: AvatarPalette.gold, size: 42), AiwaIconButton(icon: Icons.delete_outline_rounded, size: 34), and AiwaChip or status_pill for the gold Tag (padding 3x9, 11/700; verify AiwaChip supports a tonal gold variant, which was not checked). Phone text uses AppTextStyles.mono.copyWith(fontSize: 12, color: AppColors.ink3). Backend: no trusted-contact endpoints in api_constants.dart, so GET/POST/DELETE /users/me/trusted-contacts is needed; the SOS flow (other partition) consumes them. Feed the count into the Profile row value ('N saved').

### Trusted contacts - empty state — `ACCT-17` (state, missing)
- How the user reaches it: Profile -> Trusted contacts with 0 contacts (e.g. after removing the seeded 'Mona Kamal')
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:246-250
- Flutter files: none yet
- Key elements: EmptyState compact, tone gold, icon 'user-round-plus'; Title 'No trusted contact yet'; Body "Add someone you'd want alerted if you ever felt unsafe during a home service."; Primary action 'Add a contact' -> opens the inline add form
- To build: Reuse the existing EmptyState widget, which already supports compact + gold tone (empty_state.dart:6-31): EmptyState(compact: true, tone: EmptyStateTone.gold, icon: Icons.person_add_alt_outlined, title: 'No trusted contact yet', subtitle: "Add someone you'd want alerted if you ever felt unsafe during a home service.", actionLabel: 'Add a contact', onAction: () => setState(() => adding = true)). Show it only when contacts.isEmpty && !adding, below the warn InlineBanner.

### Trusted contacts - add contact inline form — `ACCT-18` (state, missing)
- How the user reaches it: Profile -> Trusted contacts -> 'Add another contact' (or 'Add a contact' from the empty state)
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:268-279
- Flutter files: none yet
- Key elements: Card paper radius 18, padding 16, 1.5px plum700 border; Eyebrow 'New trusted contact' plum700; Name (user icon, autoFocus, placeholder 'Their full name', error 'Enter their name.'); Mobile number (phone icon, placeholder '+20 100 000 0000', error 'Enter a valid mobile number.'); Relationship optional (heart icon, placeholder 'Sister, friend, partner…'; defaults to 'Contact'); Cancel (secondary md) + 'Add contact' (primary md, opacity .45 until name >= 2 chars and phone >= 9 digits)
- To build: In TrustedContactsPage keep a bool adding. Render a Container(decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.plum700, width: 1.5))) with EyebrowLabel('New trusted contact', color: AppColors.plum700), three AiwaTextFields (autoFocus on the first), and a Row of AiwaButton secondary/primary (onPressed null until canAdd). POST to the trusted-contacts endpoint (see ACCT-16).

### Remove trusted contact confirm sheet — `ACCT-19` (sheet, missing)
- How the user reaches it: Profile -> Trusted contacts -> trash icon on a contact
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:289-292
- Flutter files: none yet
- Key elements: ConfirmSheet tone danger, icon 'user-round-minus'; Eyebrow 'Safety'; title 'Remove this contact?'; Body "They'll no longer be alerted if you press SOS during a home service."; Cancel + 'Remove' -> contact removed from list (no toast)
- To build: Reuse showConfirmSheet: showConfirmSheet(context, eyebrow: 'Safety', title: 'Remove this contact?', body: "They'll no longer be alerted if you press SOS during a home service.", confirmLabel: 'Remove', icon: Icons.person_remove_outlined). If confirmed, DELETE the contact and remove it from bloc state.

### Notifications inbox (customer) — `ACCT-20` (sub-screen, deviates)
- How the user reaches it: Home -> bell icon (screens.jsx:76) or Profile tab -> 'Notifications'
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:100-172 (NOTIFICATIONS, NotificationsScreen); prototype.jsx:713
- Flutter files: Android/aiwa_app/lib/features/notifications/presentation/pages/notifications_page.dart, Android/aiwa_app/lib/features/notifications/presentation/bloc/notification_bloc.dart, Android/aiwa_app/lib/features/notifications/presentation/bloc/notification_state.dart, Android/aiwa_app/lib/features/notifications/domain/entities/notification_entity.dart, Android/aiwa_app/lib/features/notifications/data/repositories/notification_repository_impl.dart, Android/aiwa_app/lib/core/network/api_client.dart, Android/aiwa_app/lib/core/router/app_router.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: Header: IconBtn back, Eyebrow 'Inbox', h1 'Notifications' DM Serif 24 lh1.05 + '· N new' (Plus Jakarta 13/600 rose500, marginLeft 6); 'Mark all read' text button plum700 13/600, only when unread > 0; Groups 'Today' / 'Earlier' (Eyebrow, padding 0 22, marginTop 20, marginBottom 8); Row: padding 14/22, gap 12, unread bg plum100, 1px divider bottom, background transition 200ms; 38px paper tile radius 12 with 1px divider border, type icon 18 plum700 (navigation, check-circle, star, badge-check, message-circle, sparkles, file-text); Title 14 (700 unread / 600 read) lh1.2; time 11 ink3; body 12.5 ink2 lh1.45; 8px rose500 unread dot; 7 seeded customer items incl. 'Terms & policies updated'; Tap: mark read, then type 'terms' -> push('terms-reaccept'); otherwise -> setActiveStatus('onway') and push('tracking')
- Findings:
  - **[CRITICAL · interaction] Notification rows are dead: no routing to Tracking or Terms re-accept** `ACCT-20-F1`
    - Prototype: prototype.jsx:713 onOpen={(n) => { if (n?.type === 'terms') { push('terms-reaccept'); } else { setActiveStatus('onway'); push('tracking'); } }}; the row onClick marks read and then calls onOpen (customer-extras.jsx:141)
    - Flutter now: notifications_page.dart:134-140 onTap only does `if (!n.read) add(NotificationMarkReadEvent(n.id))`. NotificationEntity.referenceId (notification_entity.dart:10) is never used, and app_router.dart has no terms-reaccept or tracking route
    - Fix: onTap: () {
    if (!n.read) context.read<NotificationBloc>().add(NotificationMarkReadEvent(n.id));
    final t = n.type.toUpperCase();
    if (t.contains('TERMS') || t.contains('POLICY')) { context.push(AppRoutes.termsReaccept); }
    else if (n.referenceId != null) { context.push('/tracking/${n.referenceId}'); }
  }
  This depends on the Terms re-accept and Tracking routes owned by other partitions.
  - **[MAJOR · states] Mark read / Mark all read never clear a row's unread styling** `ACCT-20-F2`
    - Prototype: customer-extras.jsx:113 markAllRead sets every item unread:false; customer-extras.jsx:141 sets the tapped item unread:false, so the plum100 background and rose dot disappear immediately
    - Flutter now: notification_bloc.dart:76-86 _onMarkRead only emits current.copyWith(unreadCount: count - 1); notification_bloc.dart:88-96 _onMarkAll only sets unreadCount: 0. The notifications list (and NotificationEntity.read, notification_entity.dart:8) is untouched, so rows keep AppColors.plum100 + dot (notifications_page.dart:216, 268-277). Tapping again re-sends the PUT and decrements the count again
    - Fix: Add NotificationEntity copyWith({bool? read}) and in the bloc:
  emit(current.copyWith(
    notifications: [for (final x in current.notifications) x.id == event.id ? x.copyWith(read: true) : x],
    unreadCount: (current.unreadCount - 1).clamp(0, 999)));
  For mark-all, map every item to read: true. Update optimistically before awaiting the repository.
  - **[MAJOR · states] Server/offline errors leave the inbox on an endless skeleton** `ACCT-20-F3`
    - Prototype: Designed failure surfaces: OfflineBanner 'No connection — showing saved data' (states.jsx:128-145, prototype.jsx:759); ErrorState with 'Try again' (states.jsx:110-125)
    - Flutter now: api_client.dart:141-158 _ErrorInterceptor.onError uses `throw const NetworkException()` / `throw ServerException(...)` inside the interceptor. dio 5.9.2 (dio_mixin.dart:516-523, assureDioException) re-wraps these as DioException(error: ServerException), so NotificationRepositoryImpl's `on ServerException` / `on NetworkException` (notification_repository_impl.dart:28-31) never match. The DioException escapes NotificationBloc._onLoad (notification_bloc.dart:45-58) after it emitted NotificationLoading, so notifications_page.dart:83-89 shows SkeletonList forever and the ErrorState branch (72-81) is unreachable. (Inferred from reading the Dio source; not run)
    - Fix: In api_client.dart replace the throws with handler.reject(err.copyWith(error: ServerException(message: ..., statusCode: statusCode))), and in the repositories catch DioException and map it via `e.error`. Or map in the data source: try { ... } on DioException catch (e) { throw e.error is ServerException ? e.error as ServerException : ServerException(message: e.message ?? 'Something went wrong'); }

### Notification preferences (channels + quiet hours) — `ACCT-21` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'Notification preferences'
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:70-133 (NOTIF_CHANNELS, NotificationPreferencesScreen); prototype.jsx:685
- Flutter files: none yet
- Key elements: Header eyebrow 'Account', title 'Notification preferences' (DM Serif 22); SectionHeader 'Channels'; 4 rows (paper, radius 14, padding 14, 34px plum100 tile radius 10): Push notifications (bell, on), SMS (message-square, on), WhatsApp (message-circle, on), Email (mail, off); Inline toggle 40x22: track plum700 when on / divider when off; 18px white knob at left 20/2 with shadow; SectionHeader 'Quiet hours'; row 'Mute non-urgent notifications' with toggle (default on); When on: two cards 'From' 22:00 / 'To' 08:00 (Eyebrow 10px, JetBrains Mono 15 time input); hidden when off
- To build: Build lib/features/notifications/presentation/pages/notification_preferences_page.dart with route '/notification-preferences'. Reuse ScreenHeader(eyebrow: 'Account', title: 'Notification preferences'), SectionHeader (shared/widgets/section_header.dart; check it matches the kit's padding 0 22 / marginTop 22 / 12), and a shared AiwaToggle (ACCT-C04; note this screen draws its own 40x22 toggle vs the kit Toggle's 42x24). Show the time cards with AnimatedSize when quietOn; tapping a card opens showTimePicker and displays the time in AppTextStyles.mono.copyWith(fontSize: 15). State: a small cubit. Backend: ApiConstants.mePreferences = '/auth/me/preferences' (api_constants.dart:15) exists but its payload is not visible; it needs channels{push,sms,whatsapp,email} and quietHours{enabled,start,end}.

### WhatsApp support ('Talk to AIWA') — `ACCT-22` (sub-screen, missing)
- How the user reaches it: Profile tab -> 'WhatsApp support'; also Account locked -> 'Contact support'
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:263-338 (WhatsAppSupportScreen); prototype.jsx:715
- Flutter files: none yet
- Key elements: Header eyebrow 'Support', title 'Talk to AIWA'; Hero card: gradient 160deg plum700 -> plum900, radius 22, padding 24x22, radial glow rgba(231,186,182,.35); 56px bone tile radius 18 with message-circle 28; h3 'Chat with a human on WhatsApp.' DM Serif 26; body rose300 13 'We answer in Arabic or English, usually within a few minutes during support hours.'; Accent lg button 'Open WhatsApp' (external-link) -> toast 'Opening WhatsApp…'; Contact card (paper, radius 18, padding 4): WhatsApp number +20 100 555 0000; Support hours Daily · 9 AM – 11 PM; Email fallback support@aiwa.app; Languages العربية · English; 32px plum100 tiles, labels 11/600 uppercase 0.08em ink3, values 14/500; Eyebrow 'Common questions' + 4 FAQ buttons (paper, radius 14, chevron-right): 'How do I cancel a booking?', 'When does the provider get paid?', "My provider didn't show up", 'How do I become a provider?'
- To build: Build lib/features/support/presentation/pages/support_page.dart with route '/support'. The hero reuses AppTheme.heroGradient + AiwaGlow(color: Color(0xFFE7BAB6), opacity: .35) + AiwaButton(variant: accent, size: lg, icon: Icons.open_in_new_rounded). Open WhatsApp with url_launcher (already a dependency, used in my_bookings_page.dart:115): launchUrl(Uri.parse('https://wa.me/201005550000'), mode: LaunchMode.externalApplication) plus showAiwaToast('Opening WhatsApp…') (ACCT-23). Contact values should come from GET /support/contact (ApiConstants.supportContact, api_constants.dart:74), whose response shape is not visible. The FAQ rows have no target in the prototype. The Arabic text 'العربية' needs the Arabic font fallback (ACCT-C02).

### Toast: 'Opening WhatsApp…' — `ACCT-23` (toast, missing)
- How the user reaches it: Profile -> WhatsApp support -> 'Open WhatsApp'
- Prototype source: ui_kits/aiwa-app/prototype.jsx:715
- Flutter files: none yet
- Key elements: Top toast with message 'Opening WhatsApp…'; Stays on the support screen
- To build: Uses showAiwaToast (ACCT-05) right before launchUrl in SupportPage (ACCT-22).

### Permission denied - location — `ACCT-28` (screen, missing)
- How the user reaches it: User denies the OS location permission (after the location priming screen)
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:135-147 (PermissionDeniedScreen kind='location'; defined but not mounted)
- Flutter files: none yet
- Key elements: SystemScreen tone warn, icon 'circle-slash', eyebrow 'Permission needed'; Title 'Location is off.'; Body 'Turn it on in Settings, or pick your area manually and we’ll search from there.'; Primary lg 'Open Settings'; ghost sm 'Pick my area manually'
- To build: PermissionDeniedPage(kind: PermissionKind.location) on SystemScreen (Icons.block_rounded, warn tone). permission_handler ^11.3.1 is in pubspec but unused: on PermissionStatus.permanentlyDenied route here. 'Open Settings' -> openAppSettings(). The fallback should open a manual area picker (not in this partition). geolocator is already used for location.

### Permission denied - camera — `ACCT-29` (screen, missing)
- How the user reaches it: Provider signup -> verification (ID / selfie) -> camera permission denied
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:135-147 (kind='camera'; defined but not mounted)
- Flutter files: none yet
- Key elements: SystemScreen tone warn, circle-slash, eyebrow 'Permission needed'; Title 'Camera access is off.'; Body 'Verification needs a live selfie. Enable the camera in Settings, or upload photos from your files.'; Primary 'Open Settings'; ghost 'Upload from files'
- To build: Same PermissionDeniedPage with kind camera. Trigger from provider_verification_page.dart when image_picker/permission_handler reports camera denied. 'Upload from files' -> ImagePicker().pickImage(source: ImageSource.gallery). Copy map lives in system-screens.jsx:136-140.

### Permission denied - notifications — `ACCT-30` (screen, missing)
- How the user reaches it: Onboarding notification priming -> OS notification permission denied
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:135-147 (kind='notifications'; defined but not mounted)
- Flutter files: none yet
- Key elements: SystemScreen tone warn, circle-slash, eyebrow 'Permission needed'; Title 'Notifications are off.'; Body 'You’ll still see every update in your in-app inbox, but we can’t alert you when a provider is on the way.'; Primary 'Open Settings'; ghost 'Use the in-app inbox' (-> Notifications inbox)
- To build: Same PermissionDeniedPage with kind notifications. Trigger when Permission.notification.request() returns denied/permanentlyDenied (flutter_local_notifications and permission_handler are in pubspec). The fallback goes to context.push(AppRoutes.notifications) (ACCT-20).

### Personal info - saving state ('Saving…') — `ACCT-V01` (state, missing)
- How the user reaches it: Profile tab -> Personal info -> edit a field -> 'Save changes'
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:15, 66-69; toast wiring prototype.jsx:678
- Flutter files: none yet
- Key elements: Primary StickyBar button label switches from 'Save changes' to 'Saving…' for 550 ms (account-screens.jsx:67-68); Button held at opacity .45 with pointerEvents none while saving (account-screens.jsx:66); After 550 ms: onSaved -> toast 'Profile updated.' + pop (prototype.jsx:678)
- To build: Part of the missing EditProfilePage (ACCT-13). Keep a local `saving` flag (or a dedicated AuthProfileSaving state) and render AiwaButton(label: saving ? 'Saving…' : 'Save changes', loading: saving, onPressed: valid && dirty && !saving ? _save : null) in StickyBar. AiwaButton's loading pulse (aiwa_button.dart:107-109) is an acceptable stand-in for the dim. Do not emit AuthLoading from auth_bloc.dart:134, or ProfilePage flips to the guest view (ACCT-01-F6). On success call showAiwaToast('Profile updated.') (ACCT-14) and context.pop().

### Personal info - inline validation errors — `ACCT-V02` (state, missing)
- How the user reaches it: Profile tab -> Personal info -> clear or garble a field, then leave it (blur)
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:17-21, 35-38; states.jsx:171-206 (ValidatedInput)
- Flutter files: none yet
- Key elements: Errors appear only after blur (ValidatedInput touched, states.jsx:172-173); Field border 1.5px danger500 (male #2E2A26 / female #6B3A3A); leading icon turns danger500; trailing circle-alert 16 (states.jsx:195, 199); Error line 11.5 danger700 with circle-alert 11: 'Enter your full name.' (<2 chars), 'Enter a valid Egyptian mobile number.' (<9 digits), 'That email doesn’t look right.' (states.jsx:202); The error replaces the hint 'Changing this sends a verification code to the new number.' while shown; 'Save changes' stays at .45 until valid && dirty
- To build: Build it inside EditProfilePage (ACCT-13) with a FocusNode per field that sets a `touched` flag on blur, and only pass `error:` to AiwaTextField once touched. AiwaTextField does not match ValidatedInput, so adjust it or add a variant. Label: uppercase AppTextStyles.eyebrow (aiwa_text_field.dart:69) vs kit 12.5/600 ink2 sentence case. Optional marker: an 'Optional' 10/500 tag (72-79) vs ' · optional' in ink4. The prefix icon does not turn danger500 and there is no trailing circle-alert (56-58). Hint colour is ink3 (161) vs kit ink4 (states.jsx:203). Validation: name.trim().length >= 2; phone digits >= 9; email optional but must match \S+@\S+\.\S+ when non-empty.

### Address form - validation error state — `ACCT-V03` (state, missing)
- How the user reaches it: Profile -> Saved addresses -> Add new address (or pencil) -> leave Street or Building invalid and blur
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:132-134, 174-176, 204
- Flutter files: none yet
- Key elements: Street & area error 'Add the street and area so your provider can find you.' when trimmed length < 4; Building error 'Building number or name is required.' when empty; Errors shown only after blur (ValidatedInput), red 1.5px danger500 border + circle-alert; StickyBar 'Add address' / 'Save address' at opacity .45 with pointerEvents none until both are valid (account-screens.jsx:204)
- To build: Part of AddressFormPage (ACCT-07/08). Use the same touched-on-blur pattern as ACCT-V02. The Building field sits in the 1.4fr/1fr/1fr grid, so its error text must wrap inside a Flexible(flex: 14) column without overflowing (use Row with Expanded(flex: 14/10/10)). Primary button: AiwaButton(onPressed: valid ? _save : null), which dims to .45 automatically (aiwa_button.dart:112).

### Safety & policies - expanded policy (accordion open) — `ACCT-V04` (state, missing)
- How the user reaches it: Profile tab -> Safety & policies -> tap any policy row (e.g. 'Terms of service')
- Prototype source: ui_kits/aiwa-app/account-screens.jsx:85, 95-103
- Flutter files: none yet
- Key elements: One row open at a time; tapping the open row closes it (setOpen(open === d.id ? null : d.id)); Right slot chevron-down becomes chevron-up, 17 ink4 (male #A39A8E / female #B59A99); Panel below the row: margin-top 7, padding 13x15, cream bg (male #EBE5DA / female #F8E8E3), radius 13, 12.5 ink2 lh1.6; Copy: 'This is the full text of the {title lowercased}, shown in the customer's language. It stays readable offline and records which version you accepted…'; Ghost sm 'Download PDF' button with download icon (no handler in the prototype)
- To build: Part of SafetyPoliciesPage (ACCT-15). Keep `String? open` in State; wrap the panel in AnimatedSize(duration: AppTheme.dur2, curve: AppTheme.easeSoft). SettingsRow needs the `right` slot (ACCT-C03) to show Icons.expand_more_rounded / expand_less_rounded at 17 AppColors.ink4. Panel: Container(margin: EdgeInsets.only(top: 7), padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13), decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(13))). Text: AppTextStyles.micro.copyWith(fontSize: 12.5, color: AppColors.ink2, height: 1.6). Button: AiwaButton(variant: ghost, size: sm, icon: Icons.download_rounded, label: 'Download PDF'), wired to url_launcher once GET /terms/latest (api_constants.dart:77) returns a PDF URL.

### Notification preferences - quiet hours off — `ACCT-V05` (state, missing)
- How the user reaches it: Profile tab -> Notification preferences -> toggle 'Mute non-urgent notifications' off
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:81, 110-129
- Flutter files: none yet
- Key elements: Quiet-hours toggle off: track divider (male #D8CFC2 / female #EFDCD6), 18px white knob at left 2 (flow-additions-v3.jsx:114-115); The 'From' / 'To' time cards are removed entirely (rendered only when quietOn, flow-additions-v3.jsx:118); Default on first load is ON (22:00 to 08:00)
- To build: Part of NotificationPreferencesPage (ACCT-21). Render the From/To Row only when quietOn, wrapped in AnimatedSize so the card collapses smoothly. Use the shared AiwaToggle (ACCT-C04) at the 40x22 / knob-left-20/2 size this screen specifies (or accept the kit's 42x24). Persist quietHours.enabled via PATCH ApiConstants.mePreferences ('/auth/me/preferences'); the payload shape is not visible.

### Notifications inbox - all read (after 'Mark all read') — `ACCT-V06` (state, deviates)
- How the user reaches it: Profile tab (or Home bell) -> Notifications -> 'Mark all read'
- Prototype source: ui_kits/aiwa-app/customer-extras.jsx:112-113, 123, 126-130, 144, 158, 163
- Flutter files: Android/aiwa_app/lib/features/notifications/presentation/pages/notifications_page.dart, Android/aiwa_app/lib/features/notifications/presentation/bloc/notification_bloc.dart, Android/aiwa_app/lib/features/notifications/domain/entities/notification_entity.dart
- Key elements: '· N new' suffix hidden (unreadCount 0); 'Mark all read' button hidden; Every row background transparent (no plum100); Every title drops to weight 600; No rose500 unread dots
- Findings:
  - **[MAJOR · states] After 'Mark all read' the header clears but every row still looks unread** `ACCT-V06-F1`
    - Prototype: customer-extras.jsx:113 `setItems(items.map(n => ({ ...n, unread: false })))`, so rows lose the plum100 bg (144), drop to weight 600 (158) and lose the dot (163)
    - Flutter now: notification_bloc.dart:88-96 only emits current.copyWith(unreadCount: 0). The header hides '· N new' and the button (notifications_page.dart:43, 47), but rows read `!n.read` (206) and keep AppColors.plum100 (216), w700 (245-247) and the rose500 dot (268-277). Same root cause as ACCT-20-F2.
    - Fix: Add `NotificationEntity copyWith({bool? read})` in notification_entity.dart and in _onMarkAll emit `current.copyWith(notifications: [for (final n in current.notifications) n.read ? n : n.copyWith(read: true)], unreadCount: 0)` optimistically before awaiting _repository.markAllAsRead().
