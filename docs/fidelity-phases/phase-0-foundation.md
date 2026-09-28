# Foundation: shared primitives, error routing, system screens, navigation chrome

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.

## Targeted findings

- **[MINOR · tokens] Colors are centralized; only 6 raw Colors.white literals remain** `DS-C1`
  - Prototype: JSX itself uses white-alpha literals, e.g. 'rgba(255,255,255,.85)' (components.jsx:80) and 'rgba(255,255,255,.16)' / '.18' (auth-screens.jsx:721)
  - Flutter now: 'Color(0x' outside lib/core/theme: 0. 'Colors.' (excluding transparent and AppColors): 6, all Colors.white.withOpacity: provider_pending_page.dart 4 (:47 .16, :49 .18, :160 .08, :162 .12), role_choice_page.dart 1 (:134 .18), aiwa_icon_button.dart 1 (:44 .85). None contradict tokens.
  - Fix: Optionally add `static Color whiteA(double a) => AppColors.paper.withValues(alpha: a);` in app_colors.dart and replace the 6 literals so all color goes through the theme.

- **[MINOR · tokens] 116 fontSize overrides (all copyWith on AppTextStyles) with off-scale sizes** `DS-C2`
  - Prototype: Token scale 48/32/26/20/17/16/14/13/11 (css:104-112). The JSX also uses off-scale 11.5 / 12.5 / 13.5 (e.g. states.jsx:98, 138, 202).
  - Flutter now: 116 'fontSize:' in 35 files outside lib/core/theme. Top files: provider_detail_page.dart 10, dashboard_page.dart 9, booking_page.dart 9, screen_chrome.dart 7, provider_business_page.dart 6, provider_card.dart 5, my_bookings_page.dart 5. Values: 12 x19, 11.5 x17, 14 x11, 13.5 x7, 10 x6, 20 x6, 12.5 x4, 9 x1 (provider_list_item.dart:87 EyebrowLabel 9px), 54 (avatar_gender_page.dart:129), 38 (provider_detail_page.dart:412). Only splash_page.dart:254 builds a raw TextStyle with a size (test fallback). 'FontWeight.' overrides: 25 (screen_chrome 3, provider_detail_page 3, provider_card 3, notifications_page 2, splash_page 2, provider_pending_page 2, phone_entry_page 2, …). 'TextStyle(' outside theme: 5 (phone_entry_page.dart:128,136; provider_pending_page.dart:84; booking_confirmed_page.dart:68 are TextSpan color/weight overrides that inherit the family). 'GoogleFonts.' outside theme: 1 (splash_page.dart:247 markaziText).
  - Fix: Add named styles for the recurring JSX sizes (e.g. `static TextStyle get caption => _sans(fontSize: 11.5, height: 1.45, color: AppColors.ink3);`, `bodyXs` 12.5, `bodySmPlus` 13.5) plus `arabicDisplay` (Markazi) in app_text_styles.dart, and replace copyWith(fontSize:) chains. Check the 9px eyebrow against its screen JSX.

- **[MINOR · tokens] Radii are mostly inline literals: 66 BorderRadius.circular calls outside the theme, only 14 via AppTheme** `DS-C3`
  - Prototype: Tokens are r-xs 4 / sm 8 / md 12 / lg 18 / xl 24 / pill 999 (css:139-144), plus inputs 14 (README.md:37). The JSX literals themselves are mostly 14, 18, 12, 10 and 16.
  - Flutter now: There are 52 non-token radii outside lib/core/theme: 50 numeric literals plus provider_list_item.dart:36 (discover ? 18 : 16) and loading_shimmer.dart:29 (variable). The literals are 14 x16, 12 x10, 2 x5, 16 x4 (booking_page.dart:386, profile_page.dart:259, dashboard_page.dart:417, avatar_gender_page.dart:203), 10 x4 (screen_chrome.dart:186, booking_page.dart:288, my_bookings_page.dart:536, provider_business_page.dart:281), 999 x3 (status_pill.dart:19, provider_card.dart:61, saved_page.dart:245), 20 x2 (role_choice_page.dart:118, auth_choice_page.dart:186), 22 x2 (home_page.dart:254, provider_pending_page.dart:48), 6 x2, 5 x1 and 18 x1 (booking_confirmed_page.dart:93). provider_detail_page.dart:316 also has Radius.circular(28). Only AppTheme.radiusPill (7) and radiusLg (7) are referenced. Top files by raw literals: booking_page.dart 7, provider_business_page.dart 5, then screen_chrome.dart, profile_page.dart and provider_verification_page.dart with 3 each.
  - Fix: Add `radiusInput = 14`, `radiusTile = 10`, `radius16 = 16`, `radius20 = 20` and `radius22 = 22` to AppTheme (mirroring the JSX literals) and replace the inline values. Use AppTheme.radiusPill for the three 999 literals and AppTheme.radiusLg at booking_confirmed_page.dart:93.

- **[MAJOR · states] 'No spinners' rule broken by four RefreshIndicators** `DS-C4`
  - Prototype: README.md:43 'No spinners — pulse/shimmer only'; README.md:110 'No spinners anywhere — shimmer/pulse only.'
  - Flutter now: There are no CircularProgressIndicator/LinearProgressIndicator widgets. However, RefreshIndicator (a Material circular spinner during pull-to-refresh) is used at home_page.dart:99, my_bookings_page.dart:135, saved_page.dart:74 and dashboard_page.dart:121. app_theme.dart:213-215 also defines progressIndicatorTheme.
  - Fix: Replace RefreshIndicator with a custom pull-to-refresh (e.g. the custom_refresh_indicator package) that shows a pulsing rose500 dot (opacity .55 to .9, 1.1s, aiwa-pulse) or re-shows SkeletonList while reloading. Remove progressIndicatorTheme so spinners are not styled by default.

- **[MAJOR · interaction] Page transitions ignore the 320ms soft-door motion** `DS-C5`
  - Prototype: prototype.jsx:726-731 wrapper animation `aiwa-slide-in` / `aiwa-fade-in` at 320ms cubic-bezier(.32,.72,0,1); README.md:42 '320ms sheet/screen transitions'
  - Flutter now: There is no pageTransitionsTheme (app_theme.dart:99-231) and no CustomTransitionPage (grep). Pushed routes use `builder:` (platform default); tab roots use NoTransitionPage (app_router.dart:151-176).
  - Fix: See DS-33-F1/F2. Add a softDoor CustomTransitionPage helper in app_router.dart and use pageBuilder everywhere.

- **[MINOR · interaction] Press-scale feedback exists only on AiwaButton** `DS-C6`
  - Prototype: prototype.html:41-42 `button:active:not(:disabled){transform:scale(.96)}` with a 120ms soft transition applies to <button> elements only (IconBtn, Chip, TabBar items, SectionHeader/InlineBanner actions). Div cards have no :active rule (prototype.html:43 only sets a transition).
  - Flutter now: AnimatedScale press feedback exists only at aiwa_button.dart:114-117 (0.97); review_page.dart:215 is a selection-state scale. 43 of the 44 `GestureDetector(` call sites in lib/ have no press feedback, and the ones that matter are the kit-button equivalents (aiwa_icon_button.dart:61, aiwa_chip.dart:37, shell_page.dart:123, section_header.dart:39, screen_chrome.dart:358).
  - Fix: See DS-31-F1: add lib/shared/widgets/aiwa_pressable.dart (scale 0.96, 120ms, easeSoft) and use it in the kit-button equivalents only, not in card rows.

- **[MINOR · states] No keyboard focus ring or semantics** `DS-C7`
  - Prototype: states.jsx:17 `.aiwa-focusable:focus-visible{outline:2px solid #7E3A5C;outline-offset:2px}`; README.md:123
  - Flutter now: grep finds no Focus(, FocusableActionDetector, Semantics( or tooltip in lib/. GestureDetector-based shared controls cannot be focused and are not exposed as buttons to screen readers.
  - Fix: See DS-31-F2: use FocusableActionDetector + a 2px AppColors.plum500 ring in AiwaPressable, and wrap it in Semantics(button: true, label: …).

- **[MINOR · tokens] Hard-coded animation durations are off the motion scale** `DS-C8`
  - Prototype: Motion scale 120/200/320/480ms (css:171-174)
  - Flutter now: sign_in_page.dart:193 150ms; review_page.dart:217 180ms; account_setup_page.dart:184 literal 200ms (should be AppTheme.dur2); aiwa_button.dart:116 literal 120ms (no dur1 token); splash_page.dart:28 900ms
  - Fix: Snap to AppTheme.dur1 (120) or dur2 (200) once DS-04-F1 adds the missing constants, and replace the literals.

- **[MAJOR · interaction] Modal sheets opened from tab roots sit under the tab bar** `DS-C9`
  - Prototype: All sheets are mounted at the app root above the TabBar (prototype.jsx:737-768; ConfirmSheet zIndex 140 vs TabBar zIndex 30)
  - Flutter now: showModalBottomSheet without useRootNavigator at confirm_sheet.dart:24, profile_page.dart:115 (palette picker) and search_page.dart:448 (filters). Pages inside the ShellRoute (app_router.dart:145-179) push onto the shell navigator, and ShellPage's bottomNavigationBar (shell_page.dart:20, extendBody: true) paints over it.
  - Fix: Add `useRootNavigator: true` to all three calls, or centralize them in a `showAiwaSheet` helper that always sets it.

- **[MINOR · states] Error feedback goes through the success-style toast** `DS-C10`
  - Prototype: The toast only confirms successes (prototype.jsx:20-39, success500 check). Errors appear inline via ValidatedInput / InlineBanner / ErrorState (states.jsx).
  - Flutter now: `showSnackBar(SnackBar(content: Text(state.message)))` for failures at avatar_gender_page.dart:77, otp_page.dart:103, phone_entry_page.dart:77, provider_verification_page.dart:55, booking_page.dart:117 and review_page.dart:97
  - Fix: Show failures in InlineBanner(tone: BannerTone.danger) near the action, or as per-field errors, and keep the toast for success (DS-32).

- **[MINOR · components] Material Icons are used app-wide instead of Lucide** `DS-C11`
  - Prototype: README.md:49 'Icons: Lucide (24px stroke, 2px weight)'; every <Icon name=…> in the JSX
  - Flutter now: Every icon is Icons.* (no Lucide dependency in pubspec.yaml:9-70)
  - Fix: See DS-05-F1: add lucide_icons_flutter and an AiwaIcons alias file, then migrate the shared widgets first.

- **[CRITICAL · interaction] No global HTTP-status to system-screen routing and no SystemScreen shell** `ACCT-C07`
  - Prototype: system-screens.jsx:1-4: system screens 'respond to states the backend already returns (401, 423, 409)'. SystemScreen shell (system-screens.jsx:9-36): bone, padding 76/26/34, 72px toned circle with aiwa-pop, eyebrow, DM Serif 27 title, 14/1.6 body maxWidth 290, primary lg + ghost sm
  - Flutter now: api_client.dart:138-162 _ErrorInterceptor maps 401 to UnauthorizedException and everything else to ServerException (thrown, then re-wrapped by Dio). There is no 403/404/423 handling, no navigation hook, no GoRouter errorBuilder or redirect (app_router.dart:64-228), and no system_screen.dart in lib/shared/widgets
  - Fix: Add lib/shared/widgets/system_screen.dart (SystemScreen({icon, tone, eyebrow, title, body, primary, onPrimary, secondary, onSecondary})), an ApiClient.authEvents broadcast stream emitting the status codes 401 (after a failed refresh), 403 and 423, and a listener in app.dart routing to /session-expired, /forbidden and /account-locked. Add GoRouter(errorBuilder: ...) for 404 (see ACCT-24..27).


## Entries

### Color tokens & runtime gender palettes — `DS-01` (component, implemented)
- How the user reaches it: Global: every screen reads the global aiwa object (MALE_THEME applied at load, theme.jsx:66)
- Prototype source: ui_kits/aiwa-app/theme.jsx:12-66; ui_kits/aiwa-app/components.jsx:4-16; tokens/colors_and_type.css:20-88
- Flutter files: Android/aiwa_app/lib/core/theme/app_colors.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: 34 color tokens (plum/rose/gold/ink/surfaces/lines/semantic); MALE_THEME charcoal #2E2A26 / stone #B5A898 / off-white #F5F2ED; FEMALE_THEME mauve #6B3A3A / dusty rose #C4837A / blush #FDF6F4; Base plum palette overwritten at load

### Typography: font families & type scale — `DS-02` (component, deviates)
- How the user reaches it: Global: all text
- Prototype source: tokens/colors_and_type.css:96-122,183-275; ui_kits/aiwa-app/components.jsx:17-19; README.md:30-34
- Flutter files: Android/aiwa_app/lib/core/theme/app_text_styles.dart, Android/aiwa_app/lib/core/theme/app_theme.dart, Android/aiwa_app/pubspec.yaml
- Key elements: DM Serif Display display/h1/h2; Plus Jakarta Sans body/UI; JetBrains Mono data; h3/h4 = sans 600 20/17px; eyebrow 11/600/0.14em uppercase; price serif 20 tnum; line-heights 1.1/1.25/1.5/1.65

### Spacing, radii & elevation tokens — `DS-03` (component, deviates)
- How the user reaches it: Global
- Prototype source: tokens/colors_and_type.css:127-159; README.md:36-39
- Flutter files: Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: 4pt spacing s-1..s-10; radii 4/8/12/18/24/999 + inputs 14; shadow-1..4 + shadow-card (plum-tinted)

### Motion tokens & keyframes — `DS-04` (component, deviates)
- How the user reaches it: Global
- Prototype source: tokens/colors_and_type.css:166-174; ui_kits/aiwa-app/prototype.html:16-43; ui_kits/aiwa-app/states.jsx:10-19; README.md:41-43
- Flutter files: Android/aiwa_app/lib/core/theme/app_theme.dart, Android/aiwa_app/lib/shared/widgets/aiwa_button.dart
- Key elements: ease-soft (.32,.72,0,1); ease-out/in/bounce; dur 120/200/320/480; keyframes slide-in/fade-in/toast/heart-pop/pulse/shimmer/pop/drop

### Icon (Lucide helper) — `DS-05` (component, deviates)
- How the user reaches it: Global: every <Icon name=...>
- Prototype source: ui_kits/aiwa-app/components.jsx:22-41; README.md:49
- Flutter files: Android/aiwa_app/pubspec.yaml, Android/aiwa_app/lib/shared/widgets/empty_state.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/features/shell/shell_page.dart
- Key elements: Lucide UMD glyphs; default size 18; stroke currentColor, 2px stroke

### Btn (pill button, 6 variants x 3 sizes) — `DS-06` (component, deviates)
- How the user reaches it: Global, e.g. Splash -> English -> Role choice -> Continue
- Prototype source: ui_kits/aiwa-app/components.jsx:44-72; ui_kits/aiwa-app/prototype.html:41-42
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_button.dart
- Key elements: variants primary/accent/secondary/ghost/danger/dark; sizes sm 8x14/13, md 12x20/15, lg 15x26/16; 600 weight, lh 1, radius 999; transition all 200ms soft; global press scale .96

### IconBtn (round icon button) — `DS-07` (component, deviates)
- How the user reaches it: Global, e.g. any ScreenHeader back button; Home -> notifications bell (dot)
- Prototype source: ui_kits/aiwa-app/components.jsx:75-94
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_icon_button.dart
- Key elements: variants paper/plum/rose/glass; size 40, icon round(size*.45); notification dot 9px rose500; shadow 0 1px 2px

### Avatar (initial + gradient, verified badge) — `DS-08` (component, deviates)
- How the user reaches it: Global, e.g. Discover -> provider rows; Profile header
- Prototype source: ui_kits/aiwa-app/components.jsx:97-127
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_avatar.dart
- Key elements: palettes plum/rose/gold/cream 135deg gradients; DM Serif initial size*.42; verified gold500 badge clamp 14-22 with 2px white border

### Chip (default / active / tonal) — `DS-09` (component, deviates)
- How the user reaches it: Discover -> category & sort chips
- Prototype source: ui_kits/aiwa-app/components.jsx:130-144
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_chip.dart
- Key elements: padding 7x13, radius 999; 13px/500; active plum700/#fff, tonal plum100/plum700, default #fff/ink2/divider; icon 13, gap 6

### StatusPill (booking status) — `DS-10` (component, deviates)
- How the user reaches it: Bookings tab -> booking cards; Tracking
- Prototype source: ui_kits/aiwa-app/components.jsx:147-172
- Flutter files: Android/aiwa_app/lib/shared/widgets/status_pill.dart
- Key elements: 11 statuses with bg/fg/dot; padding 5x10, 12px/600, dot 7

### Stars (rating) — `DS-11` (component, deviates)
- How the user reaches it: Provider profile -> reviews; Review screen
- Prototype source: ui_kits/aiwa-app/components.jsx:175-185
- Flutter files: Android/aiwa_app/lib/shared/widgets/star_rating.dart
- Key elements: 5 polygon stars, gap 1; filled gold500, empty stroke ink4 / no fill; integer n <= value

### Eyebrow label — `DS-12` (component, implemented)
- How the user reaches it: Global, e.g. Discover header 'Find someone new'
- Prototype source: ui_kits/aiwa-app/components.jsx:188-190; tokens/colors_and_type.css:250-257
- Flutter files: Android/aiwa_app/lib/shared/widgets/eyebrow_label.dart, Android/aiwa_app/lib/core/theme/app_text_styles.dart
- Key elements: 11px / 600 / 0.14em; uppercase; ink3 default, color prop

### SectionHeader — `DS-13` (component, deviates)
- How the user reaches it: Home -> 'Trending' / 'Available now' sections
- Prototype source: ui_kits/aiwa-app/components.jsx:193-200
- Flutter files: Android/aiwa_app/lib/shared/widgets/section_header.dart
- Key elements: padding 0 22, marginTop 22, marginBottom 12; DM Serif 22 plum900 -0.01em lh 1.1; action 13/600 plum700 button

### Customer bottom TabBar (+ visibility rule) — `DS-14` (component, deviates)
- How the user reaches it: Splash -> Browse as guest -> Home (visible only on home/discover/bookings/saved/profile)
- Prototype source: ui_kits/aiwa-app/components.jsx:203-237; ui_kits/aiwa-app/prototype.jsx:564-573,721,736
- Flutter files: Android/aiwa_app/lib/features/shell/shell_page.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: 5 tabs house/search/calendar-check/heart/user; frosted rgba(255,255,255,.94) blur 20, top hairline; active pill plum100 radius 14 maxWidth 80; labels 11/600; Bookings badge dot rose500 8px; padding 8 4 26

### Skeleton / SkeletonCard / SkeletonList (shimmer loading) — `DS-15` (state, deviates)
- How the user reaches it: Discover (first 620ms, prototype.jsx:136-137,201)
- Prototype source: ui_kits/aiwa-app/states.jsx:24-55
- Flutter files: Android/aiwa_app/lib/shared/widgets/loading_shimmer.dart
- Key elements: gradient cream to hover to cream, 320px, 1.25s linear; card 64x64 r16 + bars 62%/40%/78%; list gap 10

### SkeletonTile — `DS-16` (state, deviates)
- How the user reaches it: Home carousels while loading (primitive; not mounted by any prototype screen)
- Prototype source: ui_kits/aiwa-app/states.jsx:57-65
- Flutter files: Android/aiwa_app/lib/shared/widgets/loading_shimmer.dart
- Key elements: default 132x168 r18; bars 72% h11, 46% h10, gap 8

### SkeletonRows (table skeleton) — `DS-17` (state, missing)
- How the user reaches it: Admin tables only (no mobile screen mounts it)
- Prototype source: ui_kits/aiwa-app/states.jsx:67-77
- Flutter files: none yet
- Key elements: cols x rows grid; first col 80%, others 58%, h12; row padding 16x22, divider bottom
- To build: Low priority: only admin tables use it. If a Flutter web/admin surface is added, build `SkeletonRows({int cols = 5, int rows = 5})` in loading_shimmer.dart as a Column of Rows of ShimmerBox (widthFactor .8 for column 0, .58 otherwise, height 12, gap 12), each row padded EdgeInsets.symmetric(vertical: 16, horizontal: 22) with a bottom BorderSide(AppColors.divider). Reuse ShimmerBox with the DS-15 fix.

### EmptyState — `DS-18` (state, deviates)
- How the user reaches it: Saved (no favorites, prototype.jsx:299-303); Discover no results (:202-208)
- Prototype source: ui_kits/aiwa-app/states.jsx:80-107
- Flutter files: Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: 64/52 icon circle, tones plum/rose/gold; pop-in 320ms soft; DS title 22/19; body 13.5 ink3 max 270; primary + ghost sm actions max 250; column gap 3

### ErrorState — `DS-19` (state, deviates)
- How the user reaches it: Any failed request (primitive; not mounted by any prototype screen)
- Prototype source: ui_kits/aiwa-app/states.jsx:110-125; README.md:112
- Flutter files: Android/aiwa_app/lib/shared/widgets/empty_state.dart
- Key elements: danger100 circle + triangle-alert; default title/body; Try again (rotate-cw) primary; Contact support ghost sm

### OfflineBanner — `DS-20` (banner, missing)
- How the user reaches it: Prototype header 'Preview states' -> Offline banner (overlays any customer screen)
- Prototype source: ui_kits/aiwa-app/states.jsx:128-145; ui_kits/aiwa-app/prototype.jsx:519,586,759,782
- Flutter files: none yet
- Key elements: plum900 bar at top, zIndex 90; wifi-off 15 rose300; 'No connection — showing saved data' 12.5/500 bone; Retry pill rgba(250,245,238,.16) 11.5/700; aiwa-drop 260ms
- To build: Nothing implements this. connectivity_plus ^6.0.3 is declared (pubspec.yaml:63-64) but grep finds no use in lib/. Build lib/shared/widgets/offline_banner.dart plus a ConnectivityCubit (listen to Connectivity().onConnectivityChanged and to Dio connection errors in the ApiClient interceptor, lib/core/network/api_client.dart). Mount it globally with `MaterialApp.router(builder: (ctx, child) => Stack(children: [child!, const OfflineBanner()]))` in app.dart:76-83 so it sits above all routes. Visuals: Container(color: AppColors.plum900) with padding EdgeInsets.fromLTRB(18, MediaQuery.paddingOf.top + 8, 18, 11). Row gap 10: Icon(wifi_off / Lucide wifi-off, 15, AppColors.rose300); Expanded Text('No connection — showing saved data', AppTextStyles.micro.copyWith(fontSize: 12.5, fontWeight: w500, color: AppColors.bone)); Retry pill (bg AppColors.bone.withOpacity(.16), radius pill, padding 5x12, labelSm 11.5/w700 bone) that re-checks connectivity. Enter with a slide from Offset(0,-14) plus fade over 260ms AppTheme.easeSoft. Pair it with cached data in the list blocs so 'showing saved data' is true.

### InlineBanner — `DS-21` (banner, deviates)
- How the user reaches it: Sign in (lockout notice); provider verification notice; used 19x across prototype screens
- Prototype source: ui_kits/aiwa-app/states.jsx:148-168
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: tones info/warn/danger/success/plum/gold; padding 11x13, radius 14, gap 10; icon 16; title 13/700, body 12.5 lh1.5 opacity .92; action 12/700, alignSelf center

### ValidatedInput (per-field validated text input) — `DS-22` (component, deviates)
- How the user reaches it: Profile -> Personal info / Saved addresses -> Add address (19 usages)
- Prototype source: ui_kits/aiwa-app/states.jsx:171-206; README.md:115 (auth forms use Field/TextInput, ui_kits/aiwa-app/auth-screens.jsx:19-56)
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart
- Key elements: label 12.5/600 ink2 + ' · optional'; mono counter n/max in label row; 13x14 padding, radius 14, 1.5px divider/danger border; icon turns danger on error + trailing circle-alert; error shown only after blur; hint 11.5 ink4; multiline 86px
- Findings:
  - **[MAJOR · states] Error is not gated on blur (touched)** `DS-22-F1`
    - Prototype: states.jsx:172-173 `const [touched, setTouched] = useState(false); const show = touched && error;`, with setTouched on onBlur (:197-198); README.md:115 'per-field error shown on blur'
    - Flutter now: aiwa_text_field.dart:59,115-123,131 show the error whenever `error` is non-null; there is no focus/touched tracking
    - Fix: Make it a StatefulWidget: `Focus(onFocusChange: (f) { if (!f) setState(() => _touched = true); }, child: TextFormField(...))` and use `hasError = _touched && error != null`.

### Toggle (switch) — `DS-23` (component, missing)
- How the user reaches it: Profile -> Saved addresses -> Add address -> 'Set as default' (account-screens.jsx:190)
- Prototype source: ui_kits/aiwa-app/states.jsx:209-224
- Flutter files: none yet
- Key elements: 42x24 pill; on plum700 (warn500 tone) / off divider; 18px white knob, shadow 0 1 3 rgba(42,19,32,.25); left 3 to 21, 200ms soft; focus ring
- To build: There is no Toggle/Switch anywhere in lib/ (grep for 'Switch(' returns nothing). Build lib/shared/widgets/aiwa_toggle.dart: `AiwaToggle({required bool value, required ValueChanged<bool> onChanged, AiwaToggleTone tone = plum})`. Use AnimatedContainer(width 42, height 24, radius pill, color value ? (tone==warn ? AppColors.warn500 : AppColors.plum700) : AppColors.divider, duration AppTheme.dur2, curve easeSoft) containing an AnimatedAlign/AnimatedPositioned knob (18x18 white circle, left 3 or 21, BoxShadow(color: Color(0x402A1320), blurRadius: 3, offset: Offset(0,1))). Wrap it in Semantics(toggled: value) and FocusableActionDetector for the 2px plum500 focus ring. Needed by the address form, notification preferences and provider vacation mode (screens owned by other auditors).

### ConfirmSheet (destructive / neutral confirm) — `DS-24` (sheet, deviates)
- How the user reaches it: Profile -> Sign out (prototype.jsx:756-758); Bookings -> cancel
- Prototype source: ui_kits/aiwa-app/states.jsx:227-257; ui_kits/aiwa-app/prototype.jsx:756-758
- Flutter files: Android/aiwa_app/lib/shared/widgets/confirm_sheet.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: barrier rgba(42,19,32,.48) fade 200ms; bone sheet radius 24, padding 18 22 34, slide-in 300ms; handle 40x4; 46px tone circle + icon 21; eyebrow, DS title 23 lh1.12, body 13.5 ink2; secondary + danger/primary lg buttons
- Findings:
  - **[MAJOR · interaction] Sheet opens on the shell navigator, so the tab bar stays above the barrier and remains tappable** `DS-24-F1`
    - Prototype: prototype.jsx:756-758 ConfirmSheet is mounted at the app root; states.jsx:234 `position: absolute, inset: 0, zIndex: 140` covers the TabBar (zIndex 30, components.jsx:217)
    - Flutter now: confirm_sheet.dart:24-29 showModalBottomSheet without useRootNavigator. Callers profile_page.dart:101 and my_bookings_page.dart:96 sit inside the ShellRoute (app_router.dart:145-147), and ShellPage paints bottomNavigationBar over its body (shell_page.dart:16-22, extendBody: true). The bottom padding (:40) also absorbs the tab-bar height.
    - Fix: Pass `useRootNavigator: true` in showConfirmSheet, and do the same in profile_page.dart:115 and search_page.dart:448.

### SuccessSheet — `DS-25` (sheet, missing)
- How the user reaches it: All success terminals (primitive; no prototype screen currently mounts it)
- Prototype source: ui_kits/aiwa-app/states.jsx:260-288; README.md:117
- Flutter files: none yet
- Key elements: centered bone sheet radius 24; 58px success100 circle + check 27, pop 340ms bounce; title 24 DS, body 13.5 ink2 max 280; primary lg 'Done' + ghost sm secondary
- To build: Add `Future<void> showSuccessSheet(BuildContext, {required String title, String? body, String primary = 'Done', VoidCallback? onPrimary, String? secondary, VoidCallback? onSecondary})` next to confirm_sheet.dart, using the same shell (useRootNavigator: true, barrier plum900 .48, AppTheme.sheetDecoration, handle 40x4 with mb 18, padding 18/22/34). Content is centered: 58px circle (AppColors.success100) with a check icon (27, success700) that pops in over 340ms with the DS-04 easeBounce Cubic(.34,1.56,.64,1); title AppTextStyles.h3.copyWith(fontSize: 24, height: 1.12, letterSpacing: 0); body bodySm 13.5 ink2 maxWidth 280; then AiwaButton lg fullWidth primary, and 9px below it an optional ghost sm secondary. README.md:117 says every success terminal should use it, so screens that currently use SnackBars for success could adopt it.

### Pagination — `DS-26` (component, missing)
- How the user reaches it: Admin bookings monitor / audit log (admin-modules.jsx:107,314); no mobile screen mounts it
- Prototype source: ui_kits/aiwa-app/states.jsx:291-318; README.md:118
- Flutter files: none yet
- Key elements: 32x32 radius 10 buttons; current page plum700/#fff; 3-page window + ellipsis; disabled prev/next opacity .5
- To build: Low priority for mobile: no customer/provider prototype screen mounts it (mobile lists end with EndOfList). If paginated /bookings/my or /providers/{id}/reviews needs explicit paging, build `AiwaPagination({page, totalPages, onPage, compact})` in lib/shared/widgets. Row centered, gap 6, padding top 18 bottom 6 (compact 14/4). Chevron buttons 32x32 radius 10, 1px divider border, paper bg, plum700 or ink4 at .5 opacity when disabled. Number buttons minWidth 32 with horizontal padding 9, selected plum700/white, others paper/ink2, 13/600. Show '…' ink4 when totalPages > from+2, and add a focus ring.

### EndOfList — `DS-27` (component, implemented)
- How the user reaches it: Discover -> end of results ('N providers in range', prototype.jsx:232)
- Prototype source: ui_kits/aiwa-app/states.jsx:320-328
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: hairlines either side; 11.5 ink4 label; padding 18 4 6, gap 10; default "That's everything"

### ScreenHeader — `DS-28` (component, deviates)
- How the user reaches it: Profile -> Personal info / Safety & policies / Trusted contacts (account-screens.jsx:25,88,241)
- Prototype source: ui_kits/aiwa-app/states.jsx:413-424
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: padding 60 22 8; IconBtn arrow-left; eyebrow + DS 22 title lh 1.1, mt 2; right slot

### StickyBar — `DS-29` (component, deviates)
- How the user reaches it: Personal info -> Save; Address form -> Save (account-screens.jsx:64,202)
- Prototype source: ui_kits/aiwa-app/states.jsx:427-435
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: paper bg, top hairline; padding 14 22 32; flex row, gap 10; sticky bottom, bleeds -22

### SettingsRow — `DS-30` (component, deviates)
- How the user reaches it: Profile -> Safety & policies (account-screens.jsx:95,108-109)
- Prototype source: ui_kits/aiwa-app/states.jsx:438-461 (plus ProfileScreen row, prototype.jsx:383-398)
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: boxed paper card radius 14, padding 13x14, gap 13; 36px tile radius 11, tone plum/gold/danger; label 14/600, sub 11.5 ink3, value 12.5 ink3; right slot; chevron 17 ink4 when onTap; row-hover

### Interaction state classes (press / row-hover / focus ring) — `DS-31` (state, deviates)
- How the user reaches it: Global: any button tap; keyboard focus on Toggle / Pagination / OfflineBanner Retry
- Prototype source: ui_kits/aiwa-app/prototype.html:41-43; ui_kits/aiwa-app/states.jsx:16-18; README.md:123
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_button.dart, Android/aiwa_app/lib/shared/widgets/aiwa_icon_button.dart, Android/aiwa_app/lib/shared/widgets/aiwa_chip.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/features/shell/shell_page.dart
- Key elements: button:active scale .96 at 120ms soft; [role=button]/div[onclick] transition; aiwa-row-hover #F0E8DC; aiwa-focusable 2px #7E3A5C outline, offset 2; aiwa-press .97 (unused)

### Toast overlay — `DS-32` (toast, deviates)
- How the user reaches it: Sign in -> Continue shows the toast 'Welcome back, Layla.' (prototype.jsx:621); also address saved, review submitted, etc.
- Prototype source: ui_kits/aiwa-app/prototype.jsx:20-39,735; ui_kits/aiwa-app/prototype.html:26-29
- Flutter files: Android/aiwa_app/lib/core/theme/app_theme.dart, Android/aiwa_app/lib/features/reviews/presentation/pages/review_page.dart, Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart
- Key elements: top 56, left/right 16, zIndex 200; bg rgba(42,19,32,.96), bone text, radius 14, padding 12x16; 26px success500 circle with white check 15; 13px/500; shadow 0 12px 32px rgba(74,31,56,.3), blur 8; aiwa-toast 320ms, auto-dismiss 2800ms
- Findings:
  - **[MAJOR · layout] Toast appears at the bottom instead of the top** `DS-32-F1`
    - Prototype: prototype.jsx:27 `position: 'absolute', top: 56, left: 16, right: 16, zIndex: 200`
    - Flutter now: app_theme.dart:191 `behavior: SnackBarBehavior.floating` (bottom of the Scaffold); callers e.g. review_page.dart:91-93, my_bookings_page.dart:129
    - Fix: Build lib/shared/widgets/aiwa_toast.dart with `showAiwaToast(String message)` that inserts an OverlayEntry into `rootNavigatorKey.currentState!.overlay`, positioned at `top: MediaQuery.paddingOf(ctx).top + 8, left: 16, right: 16`. Replace the success SnackBars with it.
  - **[MAJOR · components] Success check badge is missing** `DS-32-F2`
    - Prototype: prototype.jsx:33-35 26x26 circle `background: aiwa.success500` containing `<Icon name="check" size={15} color="#fff" />`, gap 10
    - Flutter now: SnackBar(content: Text(...)) only (e.g. review_page.dart:92)
    - Fix: In the toast Row: `Container(width: 26, height: 26, decoration: BoxDecoration(color: AppColors.success500, shape: BoxShape.circle), child: const Icon(Icons.check, size: 15, color: Colors.white))`, then SizedBox(width: 10), then Expanded(Text).

### Screen transitions (push / pop / tab switch) — `DS-33` (component, deviates)
- How the user reaches it: Home -> tap provider (push); back (pop); tap another tab (reset)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:547-560,564-573,726-731; ui_kits/aiwa-app/prototype.html:16-25; README.md:42,144
- Flutter files: Android/aiwa_app/lib/core/router/app_router.dart, Android/aiwa_app/lib/core/theme/app_theme.dart
- Key elements: forward: aiwa-slide-in translateX(8%) to 0, 320ms cubic-bezier(.32,.72,0,1); back: aiwa-fade-in scale .98 to 1, 320ms; tab switch resets the stack (intended fade; rendered slide because reset() sets 'forward')
- Findings:
  - **[MAJOR · interaction] Push/pop use the platform default route transition instead of the 320ms soft door** `DS-33-F1`
    - Prototype: prototype.jsx:730 `animation: ${direction === 'forward' ? 'aiwa-slide-in' : 'aiwa-fade-in'} 320ms cubic-bezier(.32,.72,0,1)`; prototype.html:16-23 slide-in translateX(8%) to 0 and fade-in scale(.98) to 1
    - Flutter now: All non-shell routes use `builder:` (app_router.dart:68-144,180-226), which gives the default MaterialPage. There is no pageTransitionsTheme in app_theme.dart:99-231, and AppTheme.dur3/easeSoft (:31-33) are never applied to routes.
    - Fix: Add a helper and switch every route to pageBuilder: `CustomTransitionPage<void> softDoor(Widget child, GoRouterState s) => CustomTransitionPage(key: s.pageKey, child: child, transitionDuration: AppTheme.dur3, reverseTransitionDuration: AppTheme.dur3, transitionsBuilder: (_, a, __, c) => SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: AppTheme.easeSoft)), child: c));`

### Gender theme swap — `DS-34` (state, deviates)
- How the user reaches it: Splash -> English -> Customer -> Sign up -> Phone -> OTP -> Account setup -> Avatar & gender (live preview) -> Terms -> Preferences -> Save (handleSavePrefs)
- Prototype source: ui_kits/aiwa-app/theme.jsx:57-68; ui_kits/aiwa-app/prototype.jsx:525-526,535,595-606,639-646,724; ui_kits/aiwa-app/auth-screens.jsx:389-400
- Flutter files: Android/aiwa_app/lib/core/theme/theme_controller.dart, Android/aiwa_app/lib/app.dart, Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart, Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart
- Key elements: applyAiwaTheme mutates the global aiwa; live preview on AvatarGender (useLayoutEffect); default signup.gender 'FEMALE'; handleSavePrefs applies and bumps themeKey to remount the tree
- Findings:
  - **[MAJOR · states] Gender step preselects MALE instead of FEMALE, so the live palette differs** `DS-34-F1`
    - Prototype: prototype.jsx:535 `gender: 'FEMALE'` feeds AvatarGenderScreen initialGender (prototype.jsx:639; auth-screens.jsx:389), and auth-screens.jsx:396-398 `useLayoutEffect(() => applyAiwaTheme(gender === 'FEMALE' ? 'female' : 'male'))`, so entering the step turns the app mauve
    - Flutter now: avatar_gender_page.dart:32-34 `late String _gender = ThemeController.mode.value == ThemeController.female ? 'FEMALE' : 'MALE';` defaults to MALE and nothing is applied on entry
    - Fix: Initialize `_gender = 'FEMALE'` and call `ThemeController.applyGender('FEMALE', persist: false)` in initState (post-frame).

### Wordmark / logo assets / app icon — `DS-35` (component, deviates)
- How the user reaches it: App launcher icon -> Splash (Wordmark height 56)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:5-13,53; assets/logo-wordmark.svg; assets/logo-wordmark-arabic.svg; assets/logo-monogram.svg; README.md:45-48
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart, Android/aiwa_app/pubspec.yaml, Android/aiwa_app/assets/, Android/aiwa_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png, Android/aiwa_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
- Key elements: SVG 320x100, text 84 DM Serif ls -2, rose dot r6 at (307,68); width = height x 3.2; monogram: #2A1320 rounded square rx28, bone 'A', rose dot; Arabic wordmark أيوة
- Findings:
  - **[MAJOR · content] Launcher icons are the default Flutter logo** `DS-35-F1`
    - Prototype: assets/logo-monogram.svg: `<rect width="120" height="120" rx="28" fill="#2A1320">`, 'A' in DM Serif #FAF5EE, dot #C77B7E (README.md:48 'app-icon monogram')
    - Flutter now: android/app/src/main/res/mipmap-*/ic_launcher.png are the template files (442/544/721/1031/1443 bytes) showing the Flutter logo; ios AppIcon Icon-App-1024x1024@1x.png is also the Flutter logo
    - Fix: Export logo-monogram.svg to a 1024px PNG and add `flutter_launcher_icons` with `adaptive_icon_background: '#2A1320'`. Run it for Android and iOS.
  - **[MAJOR · components] No logo assets are shipped (assets/ is empty)** `DS-35-F2`
    - Prototype: assets/logo-wordmark.svg, logo-wordmark-arabic.svg, logo-monogram.svg (README.md:46-48)
    - Flutter now: Android/aiwa_app/assets/{images,icons,animations} are empty folders (pubspec.yaml:80-83). There is no flutter_svg dependency. AiwaWordmark is code-drawn (screen_chrome.dart:456-490).
    - Fix: Copy the monogram into assets/images and embed it via flutter_svg. Keep the wordmark code-drawn (the SVGs rely on external CSS); after F3 it is equivalent.

### GuestLockedScreen (shared guest gate) — `DS-36` (state, deviates)
- How the user reaches it: Splash -> Browse as guest -> Home -> tap Bookings / Saved / Profile tab
- Prototype source: ui_kits/aiwa-app/customer-extras-2.jsx:11-25; ui_kits/aiwa-app/prototype.jsx:698-711
- Flutter files: Android/aiwa_app/lib/shared/widgets/guest_locked_view.dart, Android/aiwa_app/lib/features/bookings/presentation/pages/my_bookings_page.dart, Android/aiwa_app/lib/features/saved/presentation/pages/saved_page.dart, Android/aiwa_app/lib/features/profile/presentation/pages/profile_page.dart
- Key elements: 64px plum100 circle + icon 28; eyebrow 'Browsing as guest'; DS 24 title, body 13.5 ink2 max 280; primary lg 'Sign in or create account' pushes auth-gate
- Findings:
  - **[CRITICAL · interaction] CTA goes to role choice instead of the auth gate** `DS-36-F1`
    - Prototype: prototype.jsx:699,707,710 `onSignIn={() => push('auth-gate')}` opens AuthGateScreen ('Sign in to book.', Create account / I already have an account)
    - Flutter now: guest_locked_view.dart:65 `onPressed: () => context.push(AppRoutes.roleChoice)` (AppRoutes.authGate exists at app_router.dart:54,206)
    - Fix: `onPressed: () => context.push(AppRoutes.authGate)` and let AuthGatePage continue into role choice / sign-in.

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

### Session expired — `ACCT-24` (screen, missing)
- How the user reaches it: Any authenticated request returns 401 and the refresh fails (prototype: Preview states -> 'Session expired')
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:9-44 (SystemScreen, SessionExpiredScreen); prototype.jsx:682; Preview states item prototype.jsx:788
- Flutter files: none yet
- Key elements: SystemScreen shell: bone bg, padding '76px 26px 34px', centred column, spacers above and below; 72px circle warn100 / warn700 with 'clock-alert' 31, aiwa-pop 340ms; Eyebrow 'Signed out' (warn700); h1 'Your session expired.' DM Serif 27/400 lh1.1 -0.01em plum900; Body 14 ink2 lh1.6 maxWidth 290: 'For your security we sign you out after a period of inactivity. Your bookings and saved providers are all still here.'; Primary lg full 'Sign in again' -> reset('splash')
- To build: Build a shared SystemScreen widget (lib/shared/widgets/system_screen.dart; see ACCT-C07) and SessionExpiredPage with route '/session-expired'. Today a 401 is never surfaced. _AuthInterceptor (api_client.dart:106-135) calls _storage.clearAll() when the refresh fails but doesn't navigate; _ErrorInterceptor throws UnauthorizedException (api_client.dart:152-153), which Dio re-wraps; AuthBloc._onCheckSession (auth_bloc.dart:40-51) silently emits AuthUnauthenticated when /auth/me fails. Add `static final authEvents = StreamController<int>.broadcast();` to ApiClient and push 401 after a failed refresh. In app.dart listen to it: context.read<AuthBloc>().add(AuthLogoutEvent()); router.go('/session-expired'). CTA: context.go(AppRoutes.splash).
- Findings:
  - **[CRITICAL · interaction] Expired session at launch leaves the app stuck on the splash with no choices instead of 'Your session expired.'** `ACCT-24-V1`
    - Prototype: system-screens.jsx:1-4 says the recovery screens respond to the 401 the backend returns; prototype.jsx:682 'session-expired' -> SessionExpiredScreen, 'Sign in again' -> reset('splash')
    - Flutter now: secure_storage.dart:33-36 hasValidSession only checks that an access token exists, so auth_bloc.dart:40-48 calls getCurrentUser. On a 401 whose refresh fails, _AuthInterceptor clears storage (api_client.dart:129-131) and _ErrorInterceptor throws UnauthorizedException (152-153), which dio 5.9.2 re-wraps as DioException (dio_mixin.dart:516-523). AuthRepositoryImpl.getCurrentUser only catches Unauthorized/Server/NetworkException (auth_repository_impl.dart:101-107), so the error escapes _onCheckSession, nothing is emitted and AuthBloc stays AuthInitial. splash_page.dart:38-44 and 69-78 show the language/guest choices only for AuthUnauthenticated/AuthError, so the user sees the splash hero with no way forward. The same happens offline at launch. Inferred from code, not run.
    - Fix: Fix the interceptor as in ACCT-20-F3 (handler.reject(err.copyWith(error: UnauthorizedException()))) and map DioException.error in the repositories. In auth_bloc.dart _onCheckSession wrap the body in try/catch: UnauthorizedFailure -> emit(AuthUnauthenticated()) and router.go('/session-expired') (ACCT-24 page); NetworkFailure -> keep the tokens, show the OfflineBanner (ACCT-31) and retry; any other error -> emit(AuthUnauthenticated()).

### Account locked — `ACCT-25` (screen, missing)
- How the user reaches it: Sign-in or any request returns 423 / suspended account (prototype: Preview states -> 'Account locked')
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:46-53 (AccountLockedScreen); prototype.jsx:683; Preview states prototype.jsx:789
- Flutter files: none yet
- Key elements: SystemScreen tone danger: 72px danger100 circle, 'lock' danger700; Eyebrow 'Account locked'; Title 'This account is locked.'; Body 'Your account has been suspended by our team. Our support agents can explain why and what happens next.'; Primary lg 'Contact support' -> push('support'); ghost sm 'Back to sign in' -> reset('splash')
- To build: AccountLockedPage on the shared SystemScreen, route '/account-locked'. Trigger: _ErrorInterceptor (api_client.dart:148-158) has no 423 branch (per the system-screens.jsx:3-4 header the backend returns 423). Emit 423 on ApiClient.authEvents and route there; also route when UserEntity.active == false (user_entity.dart:11) after /auth/me. 'Contact support' -> context.push('/support') (ACCT-22), which requires /support to work without an authenticated session. 'Back to sign in' -> clear storage + context.go(AppRoutes.splash).

### Forbidden (no access) — `ACCT-26` (screen, missing)
- How the user reaches it: API returns 403 / deep link into another role's area (not wired in the prototype)
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:63-69 (ForbiddenScreen; defined and exported at :281 but not mounted by CustomerApp)
- Flutter files: none yet
- Key elements: SystemScreen tone danger, icon 'shield-x'; Eyebrow 'No access'; Title "You can't open this."; Body "This area belongs to a different kind of account. If you think that's wrong, contact support."; Primary lg 'Go back'
- To build: ForbiddenPage on SystemScreen (icon Icons.gpp_bad_outlined, danger tone), route '/forbidden'. Wire it from the 403 branch in api_client.dart _ErrorInterceptor via ApiClient.authEvents, and from a go_router redirect that blocks customers from provider routes (e.g. AppRoutes.providerDashboard, app_router.dart:223-226, has no role guard). 'Go back' -> context.canPop() ? context.pop() : context.go(AppRoutes.home).

### Not found — `ACCT-27` (screen, missing)
- How the user reaches it: API 404 / stale deep link / cancelled booking link (not wired in the prototype)
- Prototype source: ui_kits/aiwa-app/system-screens.jsx:55-61 (NotFoundScreen; defined but not mounted)
- Flutter files: none yet
- Key elements: SystemScreen tone plum, icon 'search-x'; Eyebrow 'Not found'; Title '${what} isn't available.' (default 'This page isn't available.'); Body 'It may have been cancelled, removed, or the link is out of date.'; Primary lg 'Go back'
- To build: NotFoundPage({String what = 'This page'}) on SystemScreen (Icons.search_off_rounded, plum tone). Set GoRouter(errorBuilder: (_, s) => const NotFoundPage()) in app_router.dart:64, which has no errorBuilder so go_router's default error screen shows. Also route to it when detail pages (provider_detail_page, booking) get ServerException(statusCode: 404). The booking-confirmed redirect (app_router.dart:197-205) currently falls back silently to bookings.

### Offline banner — `ACCT-31` (banner, missing)
- How the user reaches it: Any screen while the device loses connectivity (prototype: Preview states -> 'Offline banner'); 'Retry' hides it
- Prototype source: ui_kits/aiwa-app/states.jsx:127-145 (OfflineBanner); mounted prototype.jsx:759; Preview states 'Offline banner' prototype.jsx:782
- Flutter files: none yet
- Key elements: Absolute top bar, zIndex 90, bg plum900, text bone, padding '52px 18px 11px' (below the status bar); wifi-off icon 15 rose300; 'No connection — showing saved data' 12.5/500; 'Retry' pill: bg rgba(250,245,238,.16), radius 999, padding 5x12, 11.5/700; Enters with aiwa-drop 260ms (translateY -14 -> 0, fade)
- To build: connectivity_plus ^6.0.3 is in pubspec but unused. Add a ConnectivityCubit (stream Connectivity().onConnectivityChanged) provided in app.dart, and mount the banner globally via MaterialApp.router(builder: (ctx, child) => Stack(children: [child!, const OfflineBanner()])) (app.dart:76-83). Widget: AnimatedSlide/AnimatedOpacity 260ms easeSoft; Container(color: AppColors.plum900, padding: EdgeInsets.fromLTRB(18, MediaQuery.paddingOf(ctx).top + 6, 18, 11)) Row[Icon(Icons.wifi_off_rounded, 15, AppColors.rose300), SizedBox(10), Expanded(Text('No connection — showing saved data', 12.5 w500 bone)), pill 'Retry' (Color(0x29FAF5EE))]. Retry re-checks connectivity and re-dispatches the current page's load event. Also show it when ApiClient raises NetworkException (api_client.dart:142-147).
