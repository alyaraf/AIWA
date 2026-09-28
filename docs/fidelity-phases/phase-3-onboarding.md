# Onboarding tail: terms, preferences, permission priming, provider onboarding

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.


## Entries

### Terms & safety policy (signup) — `ONB-01` (screen, missing)
- How the user reaches it: Customer: Splash -> Continue -> Role choice (I'm here to book) -> Create account -> Phone entry -> OTP -> Account setup -> Avatar/gender -> Terms. Provider: ... Avatar/gender -> Provider business -> Provider verification -> Submit for review -> Terms
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:13-73; prototype.jsx:652-655
- Flutter files: none yet
- Key elements: Back IconBtn arrow-left (pop); Eyebrow 'Step 1 of 2'; DM Serif 30/1.05 h1 'A few promises / before you start.'; Sub 14 ink2 'AIWA's customer terms & safety policy in plain words.'; 4 cards (paper, 1px divider, radius 16, padding 14, gap 14) with 36px radius-10 plum100 icon tiles: shield-check 'Verified providers only', lock 'Your data stays private', flag 'You can always flag or complain', banknote 'Cash only — for now'; 22px radius-6 checkbox (2px ink4 border -> plum700 fill + white check, 180ms) with 13px ink2 text; 'customer terms' / 'safety policy' in plum700 w600; Primary lg full 'Agree & continue' at opacity .45 and pointer-events none until checked; On accept: acceptedTermsVersion 'v1.0.2' + termsAcceptedAt stored, push('preferences')
- To build: Create lib/features/auth/presentation/pages/terms_page.dart (StatefulWidget, bool _agree) and add AppRoutes.terms = '/terms' with a GoRoute that forwards `extra`. Layout: reuse AuthStepScaffold (non-sticky) from features/auth/presentation/widgets/step_header.dart for scroll and safe area. Children: AiwaIconButton(Icons.arrow_back_rounded) -> SizedBox(22) -> EyebrowLabel('Step 1 of 2') -> SizedBox(6) -> Text(AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05, letterSpacing: -0.6)) -> SizedBox(8) -> bodySm ink2 subtitle -> SizedBox(24) -> 4 cards (Column spacing 14; Row gap 12; padding 14; AppColors.paper; Border.all(divider); radius 16; 36x36 plum100 tile radius 10 with 18px plum700 icon; title 14 w600 ink; text 12.5 ink2 height 1.5) -> SizedBox(18) -> tappable checkbox row (AnimatedContainer 22x22 radius 6, 2px border ink4/plum700, fill plum700 when checked, Icons.check 14 white, AppTheme.easeSoft 180ms) with a Text.rich label -> Spacer -> AiwaButton(label: 'Agree & continue', size: lg, fullWidth: true, onPressed: _agree ? _accept : null). The disabled .45 opacity is already built into aiwa_button.dart:112. Data: GET ApiConstants.termsLatest?type=CUSTOMER_TERMS (the provider type for providers) to get the version and keep it in `extra`. After the account exists, POST ApiConstants.termsAccept?version=<v> (backend TermsController.java:43-46). Wiring: the AvatarGenderPage customer branch and ProviderVerificationPage both push AppRoutes.terms; move AuthRegisterEvent to the Preferences save.
- Findings:
  - **[CRITICAL · interaction] Signup skips the Terms step: account is created at Avatar/gender** `ONB-01-F1`
    - Prototype: prototype.jsx:644-645 `if (signup.role === 'PROVIDER') push('provider-business'); else push('terms');` and prototype.jsx:650 (provider) `push('terms')`
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:49-59 customer branch dispatches `AuthRegisterEvent(...)`, then :71-73 `context.go(state.user.isProvider ? AppRoutes.providerPending : AppRoutes.home)`. There is no Terms route.
    - Fix: In AvatarGenderPage._continue customer branch replace the register call with `context.push(AppRoutes.terms, extra: data);`. Build TermsPage (see buildNotes) and register at the end of Preferences.

### Preferences (area, min/max search radius, language, theme commit) — `ONB-02` (screen, missing)
- How the user reaches it: ... Avatar/gender -> Terms -> tick agreement -> Agree & continue -> Preferences (customer and provider)
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:78-157; prototype.jsx:595-606 (handleSavePrefs), 656
- Flutter files: none yet
- Key elements: Back IconBtn; Eyebrow 'Last step'; h1 30 'Where should we / look for providers?'; Sub 'We use these to tune the providers we show you. Change them any time from Profile.'; 'Your area' input: map-pin 18 plum700, default 'Maadi, Cairo', padding 13/14, 1.5px divider, radius 14, 'Use GPS' text button 12 w600 plum700; 'Search radius' eyebrow with DM Serif 18 plum900 '{min}–{max} km' readout; Two range inputs side by side (1–25, step 1, accentColor plum700) coupled so min <= max; 11px ink3 'Min · n km' / 'Max · n km'; 'App language' two equal pills: 'English' (Plus Jakarta 14 w600) / 'العربية' (Markazi Text 18); active plum700 bg + bone text, inactive paper + 1.5 divider, radius 14, padding 12/14; Spacer (min 28) then Primary lg 'Save preferences'; handleSavePrefs: applyAiwaTheme(gender) + themeKey bump; provider -> toast + reset('provider-pending'); customer -> reset('perm-location'); Gender is a pass-through from Avatar/gender (useStateF(initialGender)) with no UI control on this screen
- To build: Create lib/features/auth/presentation/pages/preferences_page.dart and AppRoutes.preferences = '/preferences'. Widgets: AuthStepScaffold, AiwaIconButton, EyebrowLabel, and AiwaTextField(icon: Icons.location_on_outlined, suffixIcon: 'Use GPS' button) for the area. For the radius, two Slider widgets in a Row (Expanded each, gap 10, min 1, max 25, divisions 24; the sliderTheme in app_theme.dart:207-212 already uses plum700), coupled with `if (v > _max) _max = v`. Show the readout in AppTextStyles.h4 (DM Serif 18 plum900) and the min/max captions in micro 11 ink3. Build the language pills as two Expanded AnimatedContainers; for the Arabic font reuse the GoogleFonts.markaziText helper at splash_page.dart:244-256. 'Use GPS' should call Geolocator.getCurrentPosition (geolocator is already a dependency). Save flow: register if deferred (AuthRegisterEvent should also send preferredLanguage, which the backend accepts at AuthRequest.Register) -> POST terms accept -> PATCH ApiConstants.mePreferences {searchRadiusMinKm, searchRadiusMaxKm} (backend limits @Min 1 / @Max 100) -> PATCH ApiConstants.meLanguage -> ThemeController.applyGender(gender), which is already applied live at avatar-gender -> provider: show the ONB-03 toast and context.go(AppRoutes.providerPending); customer: context.go(AppRoutes.permLocation). Pass user.searchRadiusMaxKm into HomeLoadEvent in place of the hardcoded 10.
- Findings:
  - **[CRITICAL · interaction] Preferences step missing; search radius is never collected** `ONB-02-F1`
    - Prototype: prototype.jsx:654 `push('preferences');` and flow-screens.jsx:81-82 `useStateF(1)` / `useStateF(5)` (min/max km), mapped to User.searchRadiusMinKm/searchRadiusMaxKm (auth-screens.jsx:5)
    - Flutter now: No page or route (app_router.dart:29-55). home_bloc.dart:37 (also :74, :97) hardcodes `radiusKm: 10,`. HomeLoadEvent (home_event.dart:9-17) has no radius field, and ApiConstants.mePreferences (api_constants.dart:15) is never called.
    - Fix: Build PreferencesPage (see buildNotes) and PATCH ApiConstants.mePreferences {searchRadiusMinKm, searchRadiusMaxKm}. Then thread the radius into Home: add `final double radiusKm;` (default 5) to HomeLoadEvent in home_event.dart, keep it in HomeBloc as `_radiusKm`, and replace the three `radiusKm: 10` at home_bloc.dart:37,74,97 with `_radiusKm`. Dispatch `HomeLoadEvent(lat: lat, lng: lng, radiusKm: user.searchRadiusMaxKm ?? 5)` from home_page.dart:82.
  - **[MAJOR · rtl] App language choice has nowhere to live; locale is hardcoded English** `ONB-02-F2`
    - Prototype: flow-screens.jsx:133-136 `{ id: 'ar', label: 'العربية', font: '"Markazi Text", serif', size: 18 }`; tokens/colors_and_type.css:277-279 `[dir="rtl"] body, [lang="ar"] body { font-family: var(--font-arabic-body); }`
    - Flutter now: Android/aiwa_app/lib/app.dart:81 `locale: const Locale('en'),`. No localizationsDelegates are visible in app.dart:75-84, and the register payload omits preferredLanguage (auth_remote_datasource.dart:69-77).
    - Fix: Hold the locale in a ValueNotifier and rebuild MaterialApp.router with `locale: Locale(lang)` plus `localizationsDelegates: GlobalMaterialLocalizations.delegates`. Persist through PATCH ApiConstants.meLanguage and send preferredLanguage on register.
  - **[MAJOR · interaction] Existing language API sends 'language' instead of 'preferredLanguage'** `ONB-02-V1`
    - Prototype: flow-screens.jsx:152 `onSave({ gender, location, radiusMin, radiusMax, lang })` feeds User.preferredLanguage (auth-screens.jsx:3; prototype.jsx:537 `preferredLanguage: 'EN'`)
    - Flutter now: auth_remote_datasource.dart:150-153 `_client.patch(ApiConstants.meLanguage, data: {'language': language})`, but backend AuthRequest.UpdateLanguage requires `@NotNull private Language preferredLanguage` (aiwa-backend/src/main/java/com/aiwa/dto/request/AuthRequest.java:56-58, enum EN/AR), so the call fails validation. It is currently reached only through auth_repository_impl.dart:131-133 and has no UI caller.
    - Fix: In auth_remote_datasource.dart:152-153 send `data: {'preferredLanguage': language.toUpperCase()}` (values 'EN' / 'AR') before wiring it to the Preferences save.

### Toast 'Account created. Verification in review.' — `ONB-03` (toast, missing)
- How the user reaches it: Provider signup: ... Provider verification -> Terms -> Preferences -> Save preferences -> toast over Provider pending
- Prototype source: ui_kits/aiwa-app/prototype.jsx:600-602; Toast at prototype.jsx:20-39
- Flutter files: none yet
- Key elements: Top toast (top 56, left/right 16), rgba(42,19,32,.96), radius 14, padding 12/16; 26px success500 circle with white check 15; 13px w500 bone message; Auto-dismiss after 2800ms, aiwa-toast slide-down 320ms
- To build: Add a shared top-toast helper (e.g. lib/shared/widgets/aiwa_toast.dart, showAiwaToast(context, message)) using an OverlayEntry that matches Toast: top insets.top+12, horizontal 16, color Color(0xF52A1320), radius 14, a 26px success500 circle with a check, 13 w500 bone text, 320ms slide from -10px, dismiss after 2800ms. Call it right before context.go(AppRoutes.providerPending) at the end of the provider Preferences save.
- Findings:
  - **[MAJOR · states] Provider account-created toast missing** `ONB-03-F1`
    - Prototype: prototype.jsx:601 `setToast('Account created. Verification in review.');`
    - Flutter now: Not present; provider_verification_page.dart:50-51 navigates with no message
    - Fix: `showAiwaToast(context, 'Account created. Verification in review.'); context.go(AppRoutes.providerPending);`

### SystemScreen (shared full-screen system message shell) — `ONB-04` (component, missing)
- How the user reaches it: Not a route by itself. It wraps Session expired, Account locked, Not found, Forbidden and Permission denied (Preview states menu / error flows).
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:9-36
- Flutter files: none yet
- Key elements: bone bg, padding 76/26/34, centred column with flex spacers above and below; 72px circle icon (tone map: plum -> plum100/plum700, danger -> danger100/danger700, warn -> warn100/warn700, info -> info100/info700), icon 31, aiwa-pop 340ms cubic-bezier(.34,1.56,.64,1); Eyebrow in tone fg; DM Serif 27/1.1, -0.01em, plum900, margin 7/9; Body 14 ink2 lh 1.6, maxWidth 290; children slot; Primary lg full + ghost sm full, gap 9
- To build: Create lib/shared/widgets/system_screen.dart: `SystemScreen({required IconData icon, SystemTone tone = SystemTone.plum, String? eyebrow, required String title, required String body, String? primary, VoidCallback? onPrimary, String? secondary, VoidCallback? onSecondary, Widget? child})`. Use Scaffold(backgroundColor: AppColors.bone) with padding EdgeInsets.fromLTRB(26, insets.top + 30, 26, insets.bottom + 34), Column(center) [Spacer, pop-in icon circle (TweenAnimationBuilder scale .86->1 and opacity 0->1, 340ms, Cubic(.34,1.56,.64,1)), SizedBox(18), EyebrowLabel(color: fg), SizedBox(7), Text(h1.copyWith(fontSize: 27, height: 1.1, letterSpacing: -0.27), center), SizedBox(9), ConstrainedBox(maxWidth 290, bodySm ink2 height 1.6), child, Spacer, AiwaButton lg primary, SizedBox(9), AiwaButton(variant: ghost, size: sm, fullWidth: true)]. The ACCT auditor's screens (session expired, locked, not found, forbidden, permission denied) reuse it.
- Findings:
  - **[MAJOR · components] Shared SystemScreen shell not implemented** `ONB-04-F1`
    - Prototype: system-screens.jsx:20-24 `width: 72, height: 72, borderRadius: '50%', background: t.bg ... animation: 'aiwa-pop 340ms ...'`
    - Flutter now: Not present in Android/aiwa_app/lib/shared/widgets/ (files: aiwa_avatar, aiwa_button, aiwa_chip, aiwa_icon_button, aiwa_text_field, confirm_sheet, empty_state, eyebrow_label, guest_locked_view, loading_shimmer, screen_chrome, section_header, star_rating, status_pill)
    - Fix: Add system_screen.dart as described in buildNotes.

### Permission priming — location (onboarding route 'perm-location') — `ONB-05` (screen, missing)
- How the user reaches it: Customer signup: ... Terms -> Preferences -> Save preferences -> reset('perm-location'). Both Allow and Deny -> reset('perm-notifications').
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:73-79, 103-132; prototype.jsx:604, 657
- Flutter files: Android/aiwa_app/lib/features/home/presentation/pages/home_page.dart
- Key elements: bone bg, padding 76/26/34, flex spacers, left-aligned; 66x66 radius-22 plum700 tile, bone map-pin icon 29, aiwa-pop animation; Eyebrow rose700 'One quick permission' (male #5C544D / female #6B3A3A); DM Serif 29/1.07, -0.02em, 'Find beauty pros near you.'; Body 14 ink2 lh 1.6 'AIWA uses your location to show providers within your chosen radius and to share live arrival updates during a home visit.'; 3 check rows (22px success100 circle, success700 check 12, 13.5 ink2, gap 11, marginTop 22): 'Only used while the app is open' / 'Never shared with other customers' / 'You can pick an area manually instead'; Primary lg 'Allow location' + ghost sm 'Choose my area manually' (gap 9)
- To build: Create lib/features/onboarding/presentation/pages/permission_priming_page.dart with `enum PermissionKind { location, notifications, camera, contacts }` and a const copy map mirroring PERMISSIONS (system-screens.jsx:72-101): icon, eyebrow, title, body, points, allow, deny. Layout: Scaffold(bone) with Padding(fromLTRB(26, insets.top + 30, 26, insets.bottom + 34)), Column(start) [Spacer, pop-in 66x66 radius-22 plum700 tile, SizedBox(20), EyebrowLabel(color: AppColors.rose700), SizedBox(7), h1 29/1.07, SizedBox(10), bodySm ink2 1.6, SizedBox(22), point rows, Spacer, AiwaButton lg, SizedBox(9), AiwaButton ghost sm]. Add route AppRoutes.permLocation = '/perm-location' and use context.go so the stack resets, like the prototype's reset. Allow: `await Geolocator.requestPermission()`, then context.go(AppRoutes.permNotifications). Deny: go to the same route. Then change HomePage._loadData to call getCurrentPosition only when checkPermission() is already whileInUse/always, with no cold request. Platform: add ACCESS_COARSE_LOCATION/ACCESS_FINE_LOCATION to android/app/src/main/AndroidManifest.xml and NSLocationWhenInUseUsageDescription to ios/Runner/Info.plist.
- Findings:
  - **[CRITICAL · interaction] Location priming step missing; OS prompt fires cold on Home** `ONB-05-F1`
    - Prototype: prototype.jsx:604 `reset('perm-location');` / :657 `<PermissionPrimingScreen kind="location" onAllow={() => reset('perm-notifications')} onDeny={() => reset('perm-notifications')} />`
    - Flutter now: home_page.dart:66-69 `var perm = await Geolocator.checkPermission(); if (perm == LocationPermission.denied) { perm = await Geolocator.requestPermission(); }` runs on the first Home build with no priming screen
    - Fix: Add PermissionPrimingPage(kind: location) on route '/perm-location' as the step after customer Preferences. Remove the requestPermission call from HomePage._loadData.
  - **[CRITICAL · interaction] No platform location permission declared, so location can never be granted** `ONB-05-F2`
    - Prototype: system-screens.jsx:78 `allow: 'Allow location'` expects a real OS grant
    - Flutter now: android/app/src/main/AndroidManifest.xml has no <uses-permission> element at all (INTERNET appears only in the debug/profile manifests). ios/Runner/Info.plist has no *UsageDescription key. Geolocator then throws, the error is swallowed at home_page.dart:80, and the app always falls back to `double lat = 30.0444, lng = 31.2357;` (home_page.dart:62).
    - Fix: Add `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`, `ACCESS_COARSE_LOCATION` and `android.permission.INTERNET` to the main manifest, and `NSLocationWhenInUseUsageDescription` to Info.plist.

### Permission priming — notifications (onboarding route 'perm-notifications') — `ONB-06` (screen, missing)
- How the user reaches it: Customer signup: ... Preferences -> perm-location (Allow or Choose my area manually) -> perm-notifications. Both buttons run finishOnboarding: reset('home') + setTab('home').
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:80-86, 103-132; prototype.jsx:608, 658
- Flutter files: none yet
- Key elements: plum700 66px tile with bell icon; Eyebrow rose700 'Stay in the loop'; Title 'Know the moment you’re confirmed.'; Body 'We’ll tell you when a provider accepts, when they’re on the way, and when it’s time for your appointment.'; Points: 'Booking updates only by default' / 'Set quiet hours any time' / 'Turn off individual channels in settings'; Primary lg 'Turn on notifications' + ghost sm 'Not now'; finishOnboarding -> Home tab with the tab bar
- To build: Reuse the PermissionPrimingPage from ONB-05 with kind notifications on route AppRoutes.permNotifications = '/perm-notifications'. Allow: `await Permission.notification.request();` (permission_handler), then context.go(AppRoutes.home). Deny: context.go(AppRoutes.home) directly. Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` for Android 13+.
- Findings:
  - **[CRITICAL · interaction] Notification priming step missing; onboarding ends at Avatar/gender** `ONB-06-F1`
    - Prototype: prototype.jsx:658 `<PermissionPrimingScreen kind="notifications" onAllow={finishOnboarding} onDeny={finishOnboarding} />`; :608 `const finishOnboarding = () => { reset('home'); setTab('home'); };`
    - Flutter now: Not present. Onboarding ends at avatar_gender_page.dart:71-73 `context.go(... AppRoutes.home)` and notification permission is never requested.
    - Fix: Add the '/perm-notifications' route using PermissionPrimingPage(kind: notifications) and end onboarding there with context.go(AppRoutes.home).

### Permission priming — camera — `ONB-07` (screen, missing)
- How the user reaches it: No caller in the prototype. It renders only through route 'permission' with s.kind === 'camera' (prototype.jsx:684), and the Preview-states dispatcher pushes 'permission' with no kind (prototype.jsx:589 `else push(k);`). Its copy fits the moment before the ID or selfie capture on Provider verification.
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:87-93, 103-132; prototype.jsx:684
- Flutter files: none yet
- Key elements: camera icon tile; Eyebrow 'Verification step'; Title 'We need your camera.'; Body 'To verify providers we capture your national ID and a live selfie. This keeps every customer safe.'; Points: 'Documents are encrypted and private' / 'Reviewed only by our verification team' / 'Never shown on your public profile'; Primary 'Open camera' + ghost 'Upload from files instead'
- To build: PermissionPrimingPage(kind: camera). Show it before the first UploadSlot capture in ProviderVerificationPage when `await Permission.camera.status` is not granted. 'Open camera' -> Permission.camera.request(), then ImagePicker().pickImage(source: ImageSource.camera). 'Upload from files instead' -> ImagePicker().pickImage(source: ImageSource.gallery). Add NSCameraUsageDescription and NSPhotoLibraryUsageDescription to Info.plist.
- Findings:
  - **[MAJOR · states] Camera priming variant not implemented** `ONB-07-F1`
    - Prototype: system-screens.jsx:88-92 `icon: 'camera', eyebrow: 'Verification step', title: 'We need your camera.' ... allow: 'Open camera', deny: 'Upload from files instead'`
    - Flutter now: Not present (no camera usage anywhere in lib/)
    - Fix: Add the camera case to the PermissionPrimingPage copy map and call it from ProviderVerificationPage before capture.

### Permission priming — contacts (trusted contact) — `ONB-08` (screen, missing)
- How the user reaches it: No caller in the prototype: only route 'permission' with kind 'contacts'. Its copy fits Profile -> Trusted contacts -> Add (the SOS feature).
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:94-100, 103-132; prototype.jsx:684
- Flutter files: none yet
- Key elements: user-round-plus icon tile; Eyebrow 'Safety feature'; Title 'Add a trusted contact.'; Body 'If you ever press SOS during a home service, we alert this person instantly with your live location.'; Points: 'Only contacted if you trigger SOS' / 'You choose exactly who' / 'Change or remove them any time'; Primary 'Choose a contact' + ghost 'Enter manually'
- To build: PermissionPrimingPage(kind: contacts), shown from the Trusted contacts add flow (owned by the ACCT/profile auditor). The simplest version avoids the runtime permission: 'Choose a contact' launches the system contact picker (Android ACTION_PICK needs no READ_CONTACTS; iOS CNContactPickerViewController needs no permission) through a small platform channel or package, and 'Enter manually' opens a name + phone form.
- Findings:
  - **[MAJOR · states] Contacts priming variant not implemented** `ONB-08-F1`
    - Prototype: system-screens.jsx:95-99 `icon: 'user-round-plus', eyebrow: 'Safety feature', title: 'Add a trusted contact.' ... allow: 'Choose a contact', deny: 'Enter manually'`
    - Flutter now: Not present
    - Fix: Add the contacts case to the PermissionPrimingPage copy map and use it in the trusted-contact add flow.

### Permission priming — in-app re-prompt (Preview states -> 'Permission priming', route 'permission') — `ONB-09` (state, missing)
- How the user reaches it: Any customer screen -> Preview states menu -> 'Permission priming' -> push('permission') -> PermissionPrimingScreen kind 'location'. Allow and Deny both pop back to the screen underneath.
- Prototype source: ui_kits/aiwa-app/prototype.jsx:589, 684, 791
- Flutter files: none yet
- Key elements: Same location priming UI as ONB-05; Pushed on top of the current stack, not a reset; onAllow={pop} / onDeny={pop}
- To build: Give PermissionPrimingPage a `popOnDone` flag and add route '/permission?kind=location' opened with context.push. Both buttons: request if Allow, then context.pop(). Trigger it from Home or Search when Geolocator.checkPermission() == LocationPermission.denied and the user asks for nearby results. deniedForever should route to the Permission denied screen (ACCT auditor).
- Findings:
  - **[MAJOR · states] Pushed (pop-back) location priming state missing** `ONB-09-F1`
    - Prototype: prototype.jsx:684 `case 'permission': return <PermissionPrimingScreen kind={s.kind || 'location'} onAllow={pop} onDeny={pop} />;`
    - Flutter now: Not present
    - Fix: Add a push-style '/permission' route that reuses PermissionPrimingPage and pops on either action.

### Terms re-accept (policy updated) — `ONB-10` (screen, missing)
- How the user reaches it: Home -> bell -> Notifications -> tap 'Terms & policies updated' (type 'terms') -> push('terms-reaccept') -> Agree & continue -> toast + pop
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:207-226; prototype.jsx:636, 713; notification seed customer-extras.jsx:107
- Flutter files: Android/aiwa_app/lib/features/notifications/presentation/pages/notifications_page.dart
- Key elements: No back button; Eyebrow rose700 'Policies updated'; DM Serif 28/1.08 'We've updated our terms.'; Body 14 ink2 lh 1.55 'AIWA's terms & safety policy changed on May 20, 2026 — mainly around cancellation penalties and provider verification. Please re-accept to keep booking.'; cream box (padding 14, radius 14, 12.5 ink2): '<strong>v1.1.0</strong> — Adds provider-cancel penalties, home-service safety requirements, and commission settlement terms.'; Spacer, then Primary lg 'Agree & continue'
- To build: Create lib/features/terms/presentation/pages/terms_reaccept_page.dart and route '/terms-reaccept'. Fetch GET ApiConstants.termsLatest for the version and change summary (TermsPolicyDto). Layout: bone Scaffold, padding (24, insets.top+26, 24, insets.bottom+16), EyebrowLabel(color: AppColors.rose700), h1.copyWith(fontSize: 28, height: 1.08), bodySm ink2, SizedBox(20), a cream Container(radius 14, padding 14) with Text.rich (bold version + summary, 12.5 ink2 h1.5), Spacer, AiwaButton lg 'Agree & continue'. On tap: POST ApiConstants.termsAccept?version=v, show the ONB-11 toast, context.pop(). Wire NotificationsPage onTap: `if (n.type.toUpperCase().contains('TERMS')) context.push('/terms-reaccept');`. For the forced variant, wrap it in PopScope(canPop: false) and add a GoRouter redirect when user.acceptedTermsVersion != latest.
- Findings:
  - **[CRITICAL · interaction] Terms re-accept screen missing; terms notification is a dead end** `ONB-10-F1`
    - Prototype: prototype.jsx:713 `onOpen={(n) => { if (n?.type === 'terms') { push('terms-reaccept'); } ...` and flow-additions-v3.jsx:223 `<Btn variant="primary" full size="lg" onClick={onAccept}>Agree & continue</Btn>`
    - Flutter now: notifications_page.dart:134-141 `onTap: () { if (!n.read) { context.read<NotificationBloc>().add(NotificationMarkReadEvent(n.id)); } }` with no navigation
    - Fix: Build TermsReacceptPage and route TERMS notifications to it (see buildNotes).

### Toast 'Thanks — terms accepted.' — `ONB-11` (toast, missing)
- How the user reaches it: Notifications -> Terms & policies updated -> Terms re-accept -> Agree & continue -> toast over Notifications (after pop)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:636; Toast prototype.jsx:20-39
- Flutter files: none yet
- Key elements: Top toast, dark rgba(42,19,32,.96), success check badge, 13 w500 bone text 'Thanks — terms accepted.', 2800ms
- To build: After a successful POST /terms/accept in TermsReacceptPage: `showAiwaToast(context, 'Thanks — terms accepted.'); context.pop();`
- Findings:
  - **[MAJOR · states] Terms-accepted confirmation toast missing** `ONB-11-F1`
    - Prototype: prototype.jsx:636 `onAccept={() => { setToast('Thanks — terms accepted.'); pop(); }}`
    - Flutter now: Not present
    - Fix: Show the toast from TermsReacceptPage on success.

### Provider business — 'Set up your studio' (Individual default) — `ONB-12` (screen, deviates)
- How the user reaches it: Splash -> Continue -> Role choice (I'm offering services) -> Set up a new studio -> Phone entry -> OTP -> Account setup -> Avatar/gender -> Provider business (Step 5 of 6)
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:481-622; prototype.jsx:647-648
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_business_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart, Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: StepHeader: back, 6 progress segments (5 filled), 'Step 5 of 6', 'Set up your studio', 'Customers will see this on your profile.'; Business name field (store icon, 'e.g. Nadia Studio'); Business type 2-col tiles Individual (user) / Shop / salon (store) + hint 'Shops can add staff members with their own calendars.'; Short bio textarea (Optional, 84px, maxLength 240, right-aligned n/240 counter, hint '2–3 lines on what makes you stand out.'); Primary category 4x2 grid: Hair, Nails, Spa, Makeup, Lashes, Skin, Massage, Other + hint 'Pick the one you do most.'; Studio address field (map-pin, default 'Maadi, Cairo', 'Use GPS' suffix) + GPS status card; Sticky paper bar with 1px top divider: Primary lg 'Continue' (disabled .45 until name >= 2 chars and a category is picked)
- Findings:
  - **[CRITICAL · interaction] Business profile (name, type, staff, bio, category, address, lat/lng) is never sent to the backend** `ONB-12-F1`
    - Prototype: prototype.jsx:648 `onContinue={(d) => { setSignup(p => ({ ...p, ...d })); push('provider-verification'); }}`; auth-screens.jsx:615 collects businessName, bio, address, primaryCategory, businessType, staff, latitude, longitude; the ProviderProfile contract is listed at auth-screens.jsx:6-7
    - Flutter now: provider_business_page.dart:55-74 puts the fields only in go_router `extra`. provider_verification_page.dart:34-43 and auth_remote_datasource.dart:69-77 send only fullName/password/role/email/phone/gender. ApiConstants.myProviderProfile (api_constants.dart:29) is never called. The backend exposes POST /provider/profile (ProviderController.java:68, body ProviderProfileRequest: businessName, bio, address, latitude, longitude, providerType, primaryCategory) and POST /provider/staff (StaffController.java:34, body StaffMemberRequest.fullName).
    - Fix: After registration, at the final Preferences save: `await dio.post(ApiConstants.myProviderProfile, data: {'businessName': d['businessName'], 'bio': d['bio'], 'address': d['address'], 'latitude': d['latitude'], 'longitude': d['longitude'], 'primaryCategory': d['primaryCategory'], 'providerType': d['businessType'] == 'shop' ? 'SHOP' : 'INDIVIDUAL'}); for (final n in d['staff'] as List<String>) { await dio.post(ApiConstants.providerStaff, data: {'fullName': n}); }`. Add `static const String providerStaff = '/provider/staff';` to api_constants.dart.

### Provider business — Shop / salon variant (staff members) — `ONB-13` (state, deviates)
- How the user reaches it: Provider business -> tap 'Shop / salon' tile
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:533-555
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_business_page.dart
- Key elements: Field 'Staff members' + 'Optional' tag; Staff name rows (user icon, placeholder 'Staff member N name'), gap 8; Remove 'x' button (danger700, 16px, padding 8), shown only when more than one row; Dashed 'Add staff member' button (1.5px dashed divider, radius 12, padding 10, plum700 13 w600, plus 14); Hint 'Add the team who'll take bookings. You can add more later.'

### Provider business — GPS status card (locked / no GPS) — `ONB-14` (state, deviates)
- How the user reaches it: Provider business -> Studio address section (tap 'Use GPS')
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:588-610, 497, 615
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_business_page.dart
- Key elements: Card: marginTop 8, padding 12, paper, 1px dashed divider, radius 12, gap 10; 36px radius-10 tile: success100/success700 + check when locked; warn100/warn700 + map-pin when not; Title 12.5 w600 ink: 'GPS locked — 30.0444, 31.2357' or 'No GPS — tap "Use GPS"'; Sub 11 ink3 'Customers nearby can find you'; Initial state: locked (useStateA(true))

### UploadSlot — empty (tap to upload) — `ONB-15` (component, deviates)
- How the user reaches it: Provider verification -> any of 'National ID — front' / 'National ID — back' / 'Live selfie'
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:627-656
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_verification_page.dart
- Key elements: Card: minHeight 110, padding 14, paper, 1.5px dashed divider, radius 14, row gap 12; 48px radius-12 plum100 tile with a 22px plum700 icon (credit-card or camera); Label 14 w600 ink + hint 11.5 ink3 lh 1.4 (marginTop 2); upload icon 18 plum700; Tap opens a hidden <input type=file accept=image/*> and reads the file
- Findings:
  - **[CRITICAL · interaction] Upload slots never capture an image; tap just toggles 'done'** `ONB-15-F1`
    - Prototype: auth-screens.jsx:637 `onClick={() => ref.current?.click()}`, :644 `<input ref={ref} type="file" accept="image/*" hidden onChange={handle} />`, and :629-635 FileReader -> onSet(dataURL)
    - Flutter now: provider_verification_page.dart:85 `onTap: () => setState(() => _idFrontDone = !_idFrontDone)` (same at :93 and :102). image_picker ^1.1.2 is in pubspec.yaml but unused.
    - Fix: Store files, not bools: `XFile? _idFront;` and `onTap: () async { final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85); if (x != null) setState(() => _idFront = x); }`. For the selfie use `source: ImageSource.camera, preferredCameraDevice: CameraDevice.front`.

### UploadSlot — uploaded state (photo preview, tap to replace) — `ONB-16` (state, deviates)
- How the user reaches it: Provider verification -> tap a slot -> choose an image
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:637-643, 657-663
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_verification_page.dart
- Key elements: The chosen photo as a center/cover background, padding 0, 1.5px solid plum700 border, radius 14, minHeight 110; Bottom overlay linear-gradient(to top, rgba(42,19,32,.7), transparent 60%); Caption: check-circle 14 + '{label} uploaded · tap to replace' (bone 12 w600); Tap reopens the file chooser (replace)
- Findings:
  - **[MAJOR · components] Uploaded slot shows a flat gradient, not the captured photo** `ONB-16-F1`
    - Prototype: auth-screens.jsx:639 `background: value ? `center/cover url(${value})` : aiwa.paper`
    - Flutter now: provider_verification_page.dart:142-146 `gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.plum500, AppColors.plum900])`
    - Fix: `decoration: BoxDecoration(image: DecorationImage(image: FileImage(File(x.path)), fit: BoxFit.cover), border: Border.all(color: AppColors.plum700, width: 1.5), borderRadius: BorderRadius.circular(14))`
  - **[MAJOR · interaction] 'Tap to replace' actually clears the upload** `ONB-16-F3`
    - Prototype: auth-screens.jsx:637 the filled slot still calls `ref.current?.click()`, so the value is kept unless a new file is chosen
    - Flutter now: provider_verification_page.dart:85 `onTap: () => setState(() => _idFrontDone = !_idFrontDone)` sets the slot back to empty
    - Fix: Point onTap to the picker from ONB-15-F1 and assign only when the result is non-null.

### Provider verification — 'Verify your identity' — `ONB-17` (screen, deviates)
- How the user reaches it: ... Avatar/gender -> Provider business -> Continue -> Provider verification (Step 6 of 6)
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:668-710; prototype.jsx:649-650
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_verification_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: StepHeader 6/6 'Verify your identity' + sub 'Upload your national ID and a live selfie. AIWA reviews every provider before they can take bookings.'; 3 UploadSlots (ID front, ID back, Live selfie), gap 10; Private-docs note: plum100 box, padding 14, radius 14, 12px plum700 lh 1.5, shield-check 16, gap 8; Sticky bar Primary lg 'Submit for review', disabled .45 until all 3 are set; Submit -> push('terms')
- Findings:
  - **[CRITICAL · interaction] Submit registers and jumps to Pending, skipping Terms, Preferences and the toast** `ONB-17-F1`
    - Prototype: prototype.jsx:649-650 `onContinue={(d) => { setSignup(p => ({ ...p, ...d })); push('terms'); }}`, then prototype.jsx:600-602 routes to provider-pending only after Save preferences
    - Flutter now: provider_verification_page.dart:31-44 `_submit()` dispatches `AuthRegisterEvent(... role: 'PROVIDER' ...)`; :50-51 `if (state is AuthAuthenticated) { context.go(AppRoutes.providerPending); }`
    - Fix: `void _submit() => context.push(AppRoutes.terms, extra: {...widget.registrationData, 'idFront': _idFront!.path, 'idBack': _idBack!.path, 'selfie': _selfie!.path});`. Register, upload and show the toast at the end of Preferences.
  - **[CRITICAL · interaction] ID and selfie are never uploaded for review** `ONB-17-F2`
    - Prototype: auth-screens.jsx:703 `onContinue({ idFront, idBack, selfie })`, the files that populate nationalIdFront/Back/selfie (auth-screens.jsx:7)
    - Flutter now: ApiConstants.providerVerification '/provider/verification/documents' (api_constants.dart:38) is referenced nowhere. The backend expects multipart nationalIdFront, nationalIdBack and selfie (VerificationController.java:53-58).
    - Fix: After registration: `await dio.post(ApiConstants.providerVerification, data: FormData.fromMap({'nationalIdFront': await MultipartFile.fromFile(front), 'nationalIdBack': await MultipartFile.fromFile(back), 'selfie': await MultipartFile.fromFile(selfie)}));`

### Provider pending — 'We're reviewing your documents.' — `ONB-18` (screen, deviates)
- How the user reaches it: Provider signup: ... Verification -> Terms -> Preferences -> Save preferences (toast) -> Provider pending. Also: Auth choice (provider) -> Sign in -> provider-pending (prototype.jsx:622).
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:715-756; prototype.jsx:600-602, 622, 651
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/provider_pending_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: Full-bleed linear-gradient(160deg, plum700 -> plum900) (flat in both themes: male #2E2A26, female #6B3A3A); Radial glow rgba(231,186,182,.45) at 30% 25%, transparent at 60%; 72px radius-22 glass tile (rgba white .16, 1px rgba white .18, backdrop blur 8) with hourglass 34; Eyebrow rose300 'Verification submitted'; DM Serif 34/1.05 bone 'We're reviewing / your documents.'; Body 14 rose300 lh 1.6 with bold bone 'under 24 hours'; 3 status rows (rgba white .08 bg, .12 border, radius 12, padding 12): check-circle rose300 x2, hourglass gold300 'Admin review in progress'; Accent lg 'Explore the app while you wait' -> reset('home') + setTab('home'); Footnote 11.5 rose300 centred 'You can browse, but bookings open after verification.'
- Findings:
  - **[MAJOR · interaction] Pending is unreachable from sign-in; reached before Terms/Preferences at signup** `ONB-18-F1`
    - Prototype: prototype.jsx:622 `if (signup.role === 'PROVIDER') { reset('provider-pending'); }` (sign-in) and :600-602 `setToast('Account created. Verification in review.'); reset('provider-pending');` (after preferences)
    - Flutter now: sign_in_page.dart:66-69 `state.user.isProvider ? AppRoutes.providerDashboard : AppRoutes.home` (same at splash_page.dart:71-74). The only entry is provider_verification_page.dart:51, straight after registration.
    - Fix: Gate on verification: `state.user.isProvider ? (state.user.providerProfile?.isApproved == true ? AppRoutes.providerDashboard : AppRoutes.providerPending) : AppRoutes.home` in sign_in_page.dart and splash_page.dart. Reach Pending from Preferences as in ONB-17-F1.

### Terms — agree checkbox gating (unchecked / checked) — `ONB-V01` (state, missing)
- How the user reaches it: Signup ... Avatar/gender (customer) or Provider verification (provider) -> Terms -> tap the checkbox or its label
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:14, 52-70
- Flutter files: none yet
- Key elements: Unchecked: 22x22 radius-6 box, 2px aiwa.ink4 border (male #A39A8E / female #B59A99), transparent fill; 'Agree & continue' at opacity .45 with pointer-events none (flow-screens.jsx:68); Checked: aiwa.plum700 fill and border (male #2E2A26 / female #6B3A3A, base #4A1F38) with white check 14; transition all 180ms cubic-bezier(.32,.72,0,1); Both the box (:53) and the label text (:62) toggle the state; Label 13px ink2 lh 1.5: 'I've read and agree to the AIWA customer terms and safety policy.' with 'customer terms' / 'safety policy' in plum700 w600 (no link handler); Row gap 10, alignItems flex-start, box marginTop 1, row marginTop 18
- To build: Inside the new TermsPage (ONB-01) keep `bool _agree = false`. Wrap the box and label in one GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _agree = !_agree)) holding a Row(crossAxisAlignment: start) with AnimatedContainer(duration: const Duration(milliseconds: 180), curve: AppTheme.easeSoft, width: 22, height: 22, margin: EdgeInsets.only(top: 1), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: _agree ? AppColors.plum700 : AppColors.ink4, width: 2), color: _agree ? AppColors.plum700 : Colors.transparent), child: _agree ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null), SizedBox(width: 10), and Expanded(Text.rich(bodySm 13 ink2 h1.5 with plum700 w600 spans)). The CTA is `AiwaButton(label: 'Agree & continue', size: lg, fullWidth: true, onPressed: _agree ? _accept : null)`; the .45 disabled opacity already exists at aiwa_button.dart:112. Wrap the row in Semantics(checked: _agree) for accessibility.

### Preferences — search radius min/max range pair — `ONB-V02` (component, missing)
- How the user reaches it: ... Terms -> Agree & continue -> Preferences -> 'Search radius' section
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:81-82, 110-127
- Flutter files: none yet
- Key elements: Header row justify space-between, align baseline, marginBottom 10: Eyebrow 'Search radius' + DM Serif Display 18 plum900 '{min}–{max} km'; Two <input type=range> side by side, flex 1 each, gap 10, min 1 max 25 step 1, accentColor plum700 (male #2E2A26 / female #6B3A3A); Coupled: moving min above max pushes max up (:118), moving max below min pushes min down (:121); Captions row 11px ink3 marginTop 4: 'Min · {n} km' left, 'Max · {n} km' right; Defaults 1 and 5 km; saved as searchRadiusMinKm / searchRadiusMaxKm
- To build: In PreferencesPage use two `Slider(min: 1, max: 25, divisions: 24)` in a Row of Expanded widgets with SizedBox(width: 10). Keep two sliders rather than a RangeSlider to match the design. The sliderTheme at app_theme.dart:207-212 already uses plum700 for the active track and thumb and divider for the inactive track. Couple them with `onChanged: (v) => setState(() { _min = v; if (v > _max) _max = v; })` and the mirror for max. Readout: `Text('${_min.round()}–${_max.round()} km', style: AppTextStyles.h4)` (DM Serif 18 plum900, app_text_styles.dart:37-38) in a Row with `crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic`. Captions use AppTextStyles.micro. On save, PATCH ApiConstants.mePreferences {searchRadiusMinKm, searchRadiusMaxKm} (backend @Min 1 / @Max 100 in UpdatePreferencesRequest.java) and feed the max into HomeLoadEvent (see the corrected ONB-02-F1).

### Preferences — App language pills (English / العربية) — `ONB-V03` (component, missing)
- How the user reaches it: ... Terms -> Agree & continue -> Preferences -> 'App language' section
- Prototype source: ui_kits/aiwa-app/flow-screens.jsx:83, 129-149
- Flutter files: none yet
- Key elements: Eyebrow 'App language' marginBottom 10; Two flex-1 buttons, gap 8, padding 12/14, radius 14, fontWeight 600; 'English' in Plus Jakarta Sans 14; 'العربية' in Markazi Text 18; Active: plum700 bg (male #2E2A26 / female #6B3A3A), bone text (male #F5F2ED / female #FDF6F4), 1.5px transparent border; Inactive: paper #FFFFFF bg, ink text (male #2E2A26 / female #2E2026), 1.5px divider border (male #D8CFC2 / female #EFDCD6); Default 'en' (flow-screens.jsx:83); the value is sent with onSave (:152)
- To build: Build a Row of two Expanded GestureDetector + AnimatedContainer(duration: AppTheme.dur2, curve: AppTheme.easeSoft, padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14), decoration: BoxDecoration(color: active ? AppColors.plum700 : AppColors.paper, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? Colors.transparent : AppColors.divider, width: 1.5))) with SizedBox(width: 8) between. English label: AppTextStyles.label.copyWith(fontSize: 14, color: active ? AppColors.bone : AppColors.ink). Arabic label: reuse the Markazi helper at splash_page.dart:244-256 with fontSize 18 and FontWeight.w600. On save, PATCH ApiConstants.meLanguage with {'preferredLanguage': 'EN'|'AR'} (see ONB-02-V1) and switch MaterialApp.router's locale (app.dart:81) through a ValueNotifier. Add `localizationsDelegates: GlobalMaterialLocalizations.delegates` (flutter_localizations is already in pubspec.yaml:12) so 'ar' flips Directionality to RTL.
