# Polish backlog — ds (minor findings)

#### Typography: font families & type scale `DS-02`
- **[MINOR · tokens] CSS h3/h4 token styles (sans 600 20/17) have no Flutter equivalent; Flutter h3/h4 are serif** `DS-02-F1`
  - Prototype: tokens/colors_and_type.css:212-227: h3 = var(--font-body) 600 20px lh 1.25 ls -0.005em; h4 = var(--font-body) 600 17px lh 1.25. These classes are never rendered: prototype.html:9-11 links only Google Fonts, the token CSS is not bundled, and JSX titles are inline DM Serif 22 (components.jsx:196, states.jsx:97, :419).
  - Flutter now: app_text_styles.dart:30-38: h3 = _serif(fontSize: 22, height: 1.15, letterSpacing: -0.22); h4 = _serif(fontSize: 18, height: 1.2). app_theme.dart:124-125 maps headlineSmall/titleLarge to them. No sans 600 20/17 style exists.
  - Fix: Add the token styles without remapping the serif titles: `static TextStyle get h3Sans => _sans(fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.1, color: AppColors.ink); static TextStyle get h4Sans => _sans(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.ink);` in app_text_styles.dart. Keep AppTextStyles.h3 (DM Serif 22), because it matches the rendered JSX titles. Only remap titleLarge/titleMedium (app_theme.dart:124-125) after checking which Material widgets read them.

#### Typography: font families & type scale `DS-02`
- **[MINOR · tokens] price style is 22px with no tracking (token is 20px, -0.02em)** `DS-02-F2`
  - Prototype: tokens/colors_and_type.css:259-266 .price: font-display 400, var(--fs-h3)=20px, letter-spacing -0.02em, tnum
  - Flutter now: app_text_styles.dart:64-69 price = _serif(fontSize: 22, height: 1, tabularFigures); no letterSpacing
  - Fix: `static TextStyle get price => _serif(fontSize: 20, color: AppColors.ink, letterSpacing: -0.4, fontFeatures: const [FontFeature.tabularFigures()]);`

#### Typography: font families & type scale `DS-02`
- **[MINOR · tokens] body-sm color, meta line-height and paragraph 1.65 line-height are off** `DS-02-F3`
  - Prototype: css:238-242 .body-sm 14px lh 1.55 color var(--color-fg-2)=ink2; css:244-248 .meta 13px lh 1.45 ink3; css:229-236 p lh var(--lh-loose)=1.65
  - Flutter now: app_text_styles.dart:47-48 bodySm color AppColors.ink; :50-51 meta height 1.4; there is no 1.65 paragraph style (bodyLg/body use 1.5)
  - Fix: Set bodySm color to AppColors.ink2 and meta height to 1.45, and add `static TextStyle get paragraph => _sans(fontSize: 16, height: 1.65, color: AppColors.ink);`

#### Typography: font families & type scale `DS-02`
- **[MINOR · tokens] Heading letter-spacing baked into h2/h3 leaks into titles that have none** `DS-02-F4`
  - Prototype: README.md:31 headlines -0.02em. JSX titles in ScreenHeader/EmptyState/ErrorState/ConfirmSheet/GuestLocked set no letterSpacing (states.jsx:97,117,248,419; customer-extras-2.jsx:19)
  - Flutter now: app_text_styles.dart:23-35 h2 letterSpacing -0.01*26, h3 -0.01*22. They are reused through copyWith in screen_chrome.dart:58, empty_state.dart:69,162, confirm_sheet.dart:75, guest_locked_view.dart:45, so these titles render -0.22 to -0.26px tighter.
  - Fix: Use h2 letterSpacing -0.02*26 per README. For the shared chrome titles, pass `letterSpacing: 0` in copyWith, or add a `titleSerif` style with no tracking.

#### Typography: font families & type scale `DS-02`
- **[MINOR · tokens] Fonts are fetched at runtime and not bundled** `DS-02-F5`
  - Prototype: tokens/styles.css:7 loads DM Serif Display ital 0/1, Plus Jakarta 400-800, JetBrains 400/600, Markazi 400-600, IBM Plex Arabic 400-600. AIWA-Prototype.html is a self-contained offline bundle.
  - Flutter now: pubspec.yaml:45-46 google_fonts: ^6.2.1; pubspec.yaml:78-83 has no fonts: section or font assets; app_text_styles.dart:106 aiwaUseGoogleFonts = true fetches over the network
  - Fix: Bundle the TTFs (assets/google_fonts/…) and declare them in pubspec. Set `GoogleFonts.config.allowRuntimeFetching = false` in main.dart so the first offline launch does not fall back to Roboto/SF.

#### Spacing, radii & elevation tokens `DS-03`
- **[MINOR · tokens] shadow3 is a single 0.18 layer instead of two layers** `DS-03-F1`
  - Prototype: css:153-154 --shadow-3: 0 12px 32px rgba(74,31,56,.14), 0 4px 10px rgba(26,19,22,.06)
  - Flutter now: app_theme.dart:86-92 shadow3 = [BoxShadow(color: plum700.withOpacity(0.18), blurRadius: 32, offset: Offset(0,12))]
  - Fix: Use alpha 0.14 and add `BoxShadow(color: AppColors.ink.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 4))`.

#### Spacing, radii & elevation tokens `DS-03`
- **[MINOR · tokens] shadow-4 and shadow-card are not defined** `DS-03-F2`
  - Prototype: css:155 --shadow-4: 0 24px 60px rgba(42,19,32,.22); css:158-159 --shadow-card: 0 2px 8px rgba(74,31,56,.05), 0 1px 2px rgba(26,19,22,.04)
  - Flutter now: Not defined in app_theme.dart (only shadow1-3 at :60-92)
  - Fix: Add `static List<BoxShadow> get shadow4 => [BoxShadow(color: AppColors.plum900.withOpacity(.22), blurRadius: 60, offset: Offset(0,24))];` and a matching `shadowCard` getter.

#### Spacing, radii & elevation tokens `DS-03`
- **[MINOR · tokens] Sheet shadow is lighter than in the prototype** `DS-03-F3`
  - Prototype: ui_kits/aiwa-app/states.jsx:240 boxShadow '0 -12px 32px rgba(42,19,32,.2)'
  - Flutter now: app_theme.dart:44-50 sheetDecoration BoxShadow(plum700.withOpacity(0.14), blur 32, offset (0,-12))
  - Fix: Use `AppColors.plum900.withOpacity(0.20)` in sheetDecoration.

#### Motion tokens & keyframes `DS-04`
- **[MINOR · tokens] Missing ease-out/ease-in/ease-bounce curves and dur-1/dur-4** `DS-04-F1`
  - Prototype: css:166-174 --ease-out (.22,.61,.36,1), --ease-in (.55,.055,.675,.19), --ease-bounce (.34,1.56,.64,1), --dur-1 120ms, --dur-4 480ms
  - Flutter now: app_theme.dart:31-33 has only easeSoft, dur2, dur3. aiwa_button.dart:116 hard-codes Duration(milliseconds: 120).
  - Fix: Add `static const Curve easeOut = Cubic(.22,.61,.36,1), easeIn = Cubic(.55,.055,.675,.19), easeBounce = Cubic(.34,1.56,.64,1); static const Duration dur1 = Duration(milliseconds: 120), dur4 = Duration(milliseconds: 480);`

#### Motion tokens & keyframes `DS-04`
- **[MINOR · interaction] No shared equivalents of the aiwa-pop / aiwa-drop / aiwa-toast keyframes** `DS-04-F2`
  - Prototype: states.jsx:13 aiwa-pop scale .86 to 1 + fade (EmptyState :95 at 320ms soft, SuccessSheet :277 at 340ms bounce); states.jsx:15 aiwa-drop translateY(-14) (OfflineBanner :135 at 260ms); prototype.html:26-29 aiwa-toast
  - Flutter now: No reusable transition widgets in lib/shared/widgets. grep finds ScaleTransition/AnimatedScale only in aiwa_button.dart:114 and review_page.dart:215.
  - Fix: Add lib/shared/widgets/aiwa_motion.dart with `AiwaPopIn` (TweenAnimationBuilder scale .86 to 1 + opacity, dur3/easeSoft) and `AiwaDropIn` (Offset(0,-14) to 0), and reuse them in EmptyState, OfflineBanner and Toast.

#### Icon (Lucide helper) `DS-05`
- **[MINOR · components] Material Icons are used instead of Lucide** `DS-05-F1`
  - Prototype: README.md:49 'Icons: Lucide (24px stroke, 2px weight)'; e.g. 'triangle-alert' (states.jsx:116), 'octagon-alert' (:152), 'sparkles' (:154), 'rotate-cw' (:120), 'house' / 'calendar-check' (components.jsx:205, 207)
  - Flutter now: pubspec.yaml:9-70 has no Lucide package. The glyphs map to Icons.warning_amber_rounded (empty_state.dart:154), Icons.report_outlined (screen_chrome.dart:299), Icons.auto_awesome_outlined (:309), Icons.refresh_rounded (empty_state.dart:183), and Icons.home_outlined / Icons.event_available_outlined (shell_page.dart:43, :51).
  - Fix: Add `lucide_icons_flutter` to pubspec and a lib/core/theme/aiwa_icons.dart alias map (e.g. `static const house = LucideIcons.house;`). Replace Icons.* with these aliases, starting with the shared widgets.

#### Icon (Lucide helper) `DS-05`
- **[MINOR · tokens] Filled/rounded Material glyph weight instead of a 2px round-cap stroke** `DS-05-F2`
  - Prototype: components.jsx:34 svg.style.stroke = color (Lucide default stroke-width 2, round caps); Stars polygon stroke 2 (components.jsx:180)
  - Flutter now: Icons.star_rounded / star_outline_rounded (star_rating.dart:29-33), Icons.check (aiwa_avatar.dart:83): filled Material shapes
  - Fix: This is resolved by adopting Lucide (F1). For stars, draw the Lucide polygon with a CustomPainter (strokeWidth 2, filled when active).

#### Btn (pill button, 6 variants x 3 sizes) `DS-06`
- **[MINOR · interaction] Press scale is 0.97 instead of 0.96** `DS-06-F1`
  - Prototype: prototype.html:41-42 `button { transition: transform 120ms cubic-bezier(.32,.72,0,1) } button:active:not(:disabled) { transform: scale(.96); }` (.aiwa-press .97 at states.jsx:18 is not used by any JSX)
  - Flutter now: aiwa_button.dart:114-117 `AnimatedScale(scale: _pressed ? 0.97 : 1, duration: 120ms, curve: easeSoft)`
  - Fix: Change 0.97 to 0.96 (or AppTheme.pressScale = 0.96) and use AppTheme.dur1 once it is added.

#### IconBtn (round icon button) `DS-07`
- **[MINOR · tokens] Glass variant has no backdrop blur and uses a theme divider instead of the literal border** `DS-07-F1`
  - Prototype: components.jsx:80 glass: background 'rgba(255,255,255,.85)', backdropFilter 'blur(8px)', border '1px solid rgba(231,221,208,.7)'
  - Flutter now: aiwa_icon_button.dart:43-47 bg Colors.white.withOpacity(0.85), border AppColors.divider.withOpacity(0.7) (male #D8CFC2), no BackdropFilter
  - Fix: Wrap the glass variant in `ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: …))`.

#### IconBtn (round icon button) `DS-07`
- **[MINOR · interaction] No press feedback** `DS-07-F2`
  - Prototype: It is a <button>, so the global `button:active{transform:scale(.96)}` applies (prototype.html:42)
  - Flutter now: aiwa_icon_button.dart:61-63 plain GestureDetector(onTap) with no scale or highlight
  - Fix: Reuse a shared AiwaPressable (AnimatedScale 0.96, 120ms, easeSoft) wrapper, as in aiwa_button.dart:114-123.

#### Avatar (initial + gradient, verified badge) `DS-08`
- **[MINOR · components] Verified-badge check is a Material glyph sized by a different rule** `DS-08-V1`
  - Prototype: components.jsx:122 `<Icon name="check" size={Math.max(8, size * 0.18)} />`, a Lucide check with a 2px stroke inside the gold500 badge.
  - Flutter now: aiwa_avatar.dart:82-86 `Icon(Icons.check, size: badgeSize * 0.6)` with badgeSize = (size*0.32).clamp(14, 22) (:45). This gives 8.45 vs 8 at avatar size 44, 12.3 vs 11.5 at 64, and 13.2 vs 14.4 at 80. The glyph is the filled Material check.
  - Fix: In aiwa_avatar.dart use `Icon(AiwaIcons.check, size: math.max(8, size * 0.18), color: AppColors.paper)` (the Lucide check from DS-05-F1).

#### Chip (default / active / tonal) `DS-09`
- **[MINOR · interaction] No press feedback** `DS-09-F1`
  - Prototype: Chip is a <button> (components.jsx:135), so global active scale .96 applies (prototype.html:42)
  - Flutter now: aiwa_chip.dart:37-38 GestureDetector(onTap) with no scale
  - Fix: Wrap in the shared AiwaPressable (scale 0.96/120ms/easeSoft).

#### StatusPill (booking status) `DS-10`
- **[MINOR · states] Unknown status falls back to a neutral pill showing the raw value** `DS-10-F1`
  - Prototype: components.jsx:161 `const m = map[status] || map.pending;` shows the Pending pill
  - Flutter now: status_pill.dart:122-128 default shows cream/ink3/ink4 with the raw `status` string
  - Fix: Return the 'pending' config in the default branch, or log the unknown enum and still show a known label.

#### Stars (rating) `DS-11`
- **[MINOR · components] Rounded Material star glyphs instead of the Lucide polygon** `DS-11-F1`
  - Prototype: components.jsx:180 `<polygon points="12 2 15.09 8.26 …"/>` strokeWidth 2
  - Flutter now: star_rating.dart:29-33 Icons.star_half_rounded / star_rounded / star_outline_rounded
  - Fix: Paint the polygon with a CustomPainter (or use the Lucide star from DS-05).

#### Stars (rating) `DS-11`
- **[MINOR · tokens] Empty stars use divider instead of an ink4 outline** `DS-11-F2`
  - Prototype: components.jsx:180 empty: fill 'none', stroke aiwa.ink4 (male #A39A8E)
  - Flutter now: star_rating.dart:27,35 emptyColor = AppColors.divider (male #D8CFC2) applied to star_outline_rounded
  - Fix: Default `inactiveColor` to AppColors.ink4.

#### Stars (rating) `DS-11`
- **[MINOR · states] Half-star rendering differs from the prototype's integer fill** `DS-11-F3`
  - Prototype: components.jsx:179 `n <= value` so 4.8 shows 4 filled + 1 empty
  - Flutter now: star_rating.dart:23-25 shows a half star when the fraction is >= .5 (4.8 shows 4 + half)
  - Fix: Match the prototype with `final filled = i + 1 <= value;`, or confirm half-stars as an intended enhancement.

#### Stars (rating) `DS-11`
- **[MINOR · layout] No 1px gap between stars** `DS-11-F4`
  - Prototype: components.jsx:177 `display: 'inline-flex', gap: 1`
  - Flutter now: star_rating.dart:20-22 Row with no spacing
  - Fix: Add `spacing: 1` to the Row (Flutter >=3.27) or wrap the icons in Padding(right: 1).

#### SectionHeader `DS-13`
- **[MINOR · interaction] Action is bare text with no press feedback and a tiny hit area** `DS-13-F1`
  - Prototype: components.jsx:197 action is a <button> (global active scale .96, prototype.html:42)
  - Flutter now: section_header.dart:39-45 GestureDetector around a Text; hit area is the glyph box only, with no feedback
  - Fix: Wrap the action in the shared AiwaPressable with `behavior: HitTestBehavior.opaque` and Padding(vertical: 6).

#### Customer bottom TabBar (+ visibility rule) `DS-14`
- **[MINOR · components] Bookings badge dot is missing** `DS-14-F1`
  - Prototype: components.jsx:207 `badge: true`; :229 8x8 rose500 dot, top -2 right -4, border '2px solid #fff'
  - Flutter now: shell_page.dart:136-151 renders only the Icon and label; no badge
  - Fix: Wrap the Icon in `Stack(clipBehavior: Clip.none, children:[Icon(...), if (badge) Positioned(top:-2, right:-4, child: Container(width:8,height:8, decoration: BoxDecoration(color: AppColors.rose500, shape: BoxShape.circle, border: Border.all(color: AppColors.paper, width: 2))))])`, driven by a pending-bookings count.

#### Customer bottom TabBar (+ visibility rule) `DS-14`
- **[MINOR · layout] Active pill shrink-wraps its label instead of filling up to 80px** `DS-14-F2`
  - Prototype: components.jsx:225 button `flex: 1, maxWidth: 80`: each tab is about 77px wide on a 393px frame, so the plum100 pill is about 77px
  - Flutter now: shell_page.dart:126-131 Center > AnimatedContainer(constraints: maxWidth 80) is loose, so the pill is label width + 24 (about 54px for 'Home')
  - Fix: `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 80), child: SizedBox(width: double.infinity, child: AnimatedContainer(...)))`

#### Customer bottom TabBar (+ visibility rule) `DS-14`
- **[MINOR · interaction] Tab items give no press feedback** `DS-14-F3`
  - Prototype: Tabs are <button> elements (components.jsx:222), so global active scale .96 applies (prototype.html:42)
  - Flutter now: shell_page.dart:123-125 GestureDetector with no scale
  - Fix: Use the shared AiwaPressable around _TabItem.

#### Customer bottom TabBar (+ visibility rule) `DS-14`
- **[MINOR · responsive] Bottom padding is 8 + safe inset instead of 26** `DS-14-F4`
  - Prototype: components.jsx:216 `padding: '8px 4px 26px'`
  - Flutter now: shell_page.dart:78-83 `EdgeInsets.fromLTRB(4, 8, 4, 8 + MediaQuery.paddingOf(context).bottom)` gives 42 on a 34pt-inset iPhone and 8 on 3-button Android
  - Fix: `bottom: math.max(26.0, MediaQuery.paddingOf(context).bottom)`

#### Skeleton / SkeletonCard / SkeletonList (shimmer loading) `DS-15`
- **[MINOR · tokens] Shimmer highlights to white at 1.5s instead of hover at 1.25s** `DS-15-F1`
  - Prototype: states.jsx:28-30 `linear-gradient(90deg, ${aiwa.cream} 0%, ${aiwa.hover} 50%, ${aiwa.cream} 100%)`, `aiwa-shimmer 1.25s linear infinite`
  - Flutter now: loading_shimmer.dart:21-23 `Shimmer.fromColors(baseColor: AppColors.cream, highlightColor: AppColors.paper)` (package default period 1500ms)
  - Fix: `Shimmer.fromColors(baseColor: AppColors.cream, highlightColor: AppColors.hover, period: const Duration(milliseconds: 1250), …)`

#### SkeletonTile `DS-16`
- **[MINOR · layout] Default tile size is 200x110 instead of 132x168** `DS-16-F1`
  - Prototype: states.jsx:57 `SkeletonTile({ w = 132, h = 168 })`
  - Flutter now: loading_shimmer.dart:100 `this.width = 200, this.height = 110`; used with defaults at home_page.dart:443
  - Fix: Change the defaults to 132/168. If the home carousel is really 200x110, pass explicit sizes at the call site.

#### EmptyState `DS-18`
- **[MINOR · layout] Vertical rhythm is 3px tighter at each step** `DS-18-F1`
  - Prototype: states.jsx:90 column `gap: 3` plus icon mb 14, body mt 6, actions mt 18, giving 17/9/21
  - Flutter now: empty_state.dart:66,73,88 SizedBox 14 / 6 / 18
  - Fix: Use SizedBox(height: 17), (9), (21).

#### EmptyState `DS-18`
- **[MINOR · interaction] Icon circle has no pop-in animation** `DS-18-F2`
  - Prototype: states.jsx:95 `animation: 'aiwa-pop 320ms cubic-bezier(.32,.72,0,1)'` (scale .86 to 1, opacity 0 to 1)
  - Flutter now: empty_state.dart:60-65 static Container
  - Fix: Wrap it in `TweenAnimationBuilder<double>(tween: Tween(begin: .86, end: 1), duration: AppTheme.dur3, curve: AppTheme.easeSoft, builder: (_, v, c) => Opacity(opacity: (v - .86) / .14, child: Transform.scale(scale: v, child: c)))`.

#### EmptyState `DS-18`
- **[MINOR · components] Buttons hide unless a callback is also passed** `DS-18-F3`
  - Prototype: states.jsx:99-103 renders `action` / `secondary` whenever the label is set
  - Flutter now: empty_state.dart:86-87,93,99 require both actionLabel && onAction
  - Fix: Render when the label is non-null, and pass onAction (possibly null, which makes it disabled).

#### EmptyState `DS-18`
- **[MINOR · tokens] Title gets -0.22px tracking the prototype does not have** `DS-18-F4`
  - Prototype: states.jsx:97 h3 DM Serif 22/19, lh 1.15, no letterSpacing
  - Flutter now: empty_state.dart:69 AppTextStyles.h3.copyWith(fontSize: …) inherits letterSpacing -0.22 (app_text_styles.dart:34)
  - Fix: Add `letterSpacing: 0` to the copyWith (see DS-02-F4).

#### ErrorState `DS-19`
- **[MINOR · components] ErrorState has no optional 'Contact support' secondary action** `DS-19-F1`
  - Prototype: states.jsx:110,121 `onSupport && <Btn variant="ghost" full size="sm">Contact support</Btn>`; README.md:112 'with Try-again and Contact-support'. No prototype screen mounts ErrorState, so the button is never rendered in the prototype.
  - Flutter now: empty_state.dart:121-133: ErrorState has only onRetry, with no onSupport parameter or button.
  - Fix: Add `final VoidCallback? onSupport;` and, 8px below Try again, render `AiwaButton(label: 'Contact support', variant: AiwaButtonVariant.ghost, size: AiwaButtonSize.sm, fullWidth: true, onPressed: onSupport)` when it is non-null. Wire it to the WhatsApp support route wherever ErrorState is used.

#### ErrorState `DS-19`
- **[MINOR · tokens] Title gets -0.22px tracking** `DS-19-F2`
  - Prototype: states.jsx:117 no letterSpacing
  - Flutter now: empty_state.dart:162 AppTextStyles.h3.copyWith(fontSize: …)
  - Fix: Add `letterSpacing: 0`.

#### InlineBanner `DS-21`
- **[MINOR · tokens] Body text drops the .92 opacity** `DS-21-F1`
  - Prototype: states.jsx:163 body `fontSize: 12.5, color: t.fg, lineHeight: 1.5, opacity: .92`
  - Flutter now: screen_chrome.dart:345-353 body color fg at full opacity
  - Fix: `color: fg.withOpacity(0.92)`

#### InlineBanner `DS-21`
- **[MINOR · layout] Action is top-aligned instead of vertically centred** `DS-21-F2`
  - Prototype: states.jsx:165 action `alignSelf: 'center'`
  - Flutter now: screen_chrome.dart:323-324 Row(crossAxisAlignment: start), and the action at :357-369 inherits it
  - Fix: Wrap the action in `Align(alignment: Alignment.centerRight, heightFactor: null)` or use `IntrinsicHeight` + `Center`.

#### InlineBanner `DS-21`
- **[MINOR · layout] Action sits 8px from the text column instead of 10px** `DS-21-V1`
  - Prototype: states.jsx:159 container `display: 'flex', gap: 10`, which separates the text column (:161) from the action button (:165).
  - Flutter now: screen_chrome.dart:360-361 `Padding(padding: const EdgeInsets.only(left: 8), child: Text(action!...))`
  - Fix: Change it to `EdgeInsets.only(left: 10)` so it matches the icon-to-text gap (SizedBox(width: 10) at :330).

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · components] No trailing alert icon, and the prefix icon does not turn red on error** `DS-22-F2`
  - Prototype: states.jsx:195 icon color `show ? aiwa.danger500 : aiwa.plum700`; :199 `{show && <Icon name="circle-alert" size={16} color={aiwa.danger500} />}`
  - Flutter now: aiwa_text_field.dart:56-58 prefix is always AppColors.plum700; suffixIcon is caller-supplied only (:111)
  - Fix: `suffixIcon: hasError ? Icon(Icons.error_outline, size: 16, color: AppColors.danger500) : suffixIcon` and a prefix color of `hasError ? AppColors.danger500 : AppColors.plum700`.

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · tokens] Label, hint, counter and focus styling differ** `DS-22-F3`
  - Prototype: states.jsx:183 label 12.5/600 ink2 (sentence case); :186 counter fontMono 11 ink4 in the label row; :203 hint 11.5 ink4; :174 border divider (no focus color)
  - Flutter now: aiwa_text_field.dart:69 label `label!.toUpperCase()` with AppTextStyles.eyebrow (11/600/0.14em ink3); :165-169 counter in micro (Plus Jakarta 11, ink3) below the field; :161 hint in micro ink3; :119-121 focusedBorder plum700
  - Fix: Add a `labelStyle` mode: `Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 12.5, color: AppColors.ink2))`. Move the counter into the label Row as `AppTextStyles.mono.copyWith(fontSize: 11, color: AppColors.ink4)`. Set hint color ink4. Keep the eyebrow mode for the auth Field usage.

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · content] Optional marker copy and placement differ** `DS-22-F4`
  - Prototype: states.jsx:184 inline suffix ' · optional' in ink4 w400
  - Flutter now: aiwa_text_field.dart:71-79 right-aligned 'Optional' 10/500 ink3 (this is Field's style, auth-screens.jsx:23)
  - Fix: In ValidatedInput mode, render `TextSpan(text: ' · optional', style: …ink4, w400)` after the label.

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · states] Character counter does not update while typing** `DS-22-F5`
  - Prototype: states.jsx:186 counter re-renders on every change ((value||'').length)
  - Flutter now: aiwa_text_field.dart:165-169 StatelessWidget reads controller!.text.length only at build
  - Fix: `ValueListenableBuilder<TextEditingValue>(valueListenable: controller!, builder: (_, v, __) => Text('${v.text.length}/$maxLength', …))`

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · layout] No built-in 14px bottom margin; multiline padding and height differ** `DS-22-F6`
  - Prototype: states.jsx:180 wrapper marginBottom 14; :191 multiline padding '12px 14px'; :197 textarea height 86, lineHeight 1.5
  - Flutter now: aiwa_text_field.dart:61-174 has no bottom spacing; :124-127 multiline vertical padding 14; height comes from maxLines
  - Fix: Add a `bottomSpacing = 14` SizedBox, and for multiline use vertical 12 with `minLines: 3` (about 86px at 15px x 1.5).

#### ValidatedInput (per-field validated text input) `DS-22`
- **[MINOR · tokens] Error row icon is 12px with a 4px gap instead of 11px with 5px** `DS-22-V1`
  - Prototype: states.jsx:202 error row `display: 'flex', gap: 5` with `<Icon name="circle-alert" size={11} />`, text 11.5 danger700.
  - Flutter now: aiwa_text_field.dart:135-140 `Icon(Icons.error_outline_rounded, size: 12, color: AppColors.danger700)`, `SizedBox(width: 4)`. This is the auth Field style (auth-screens.jsx:27-28), not the ValidatedInput style.
  - Fix: In the ValidatedInput mode proposed in DS-22-F3, use `size: 11` and `SizedBox(width: 5)`.

#### ConfirmSheet (destructive / neutral confirm) `DS-24`
- **[MINOR · interaction] Enter animation differs** `DS-24-F2`
  - Prototype: states.jsx:236 barrier `aiwa-fade-in 200ms` (scale .98 to 1, prototype.html:20-23); :241 sheet `aiwa-slide-in 300ms cubic-bezier(.32,.72,0,1)` (translateX 8% to 0, prototype.html:16-19)
  - Flutter now: Default ModalBottomSheetRoute vertical slide-up with Material default duration/curve
  - Fix: Pass `sheetAnimationStyle: AnimationStyle(duration: AppTheme.dur3, curve: AppTheme.easeSoft)` (Flutter >=3.22). Optionally wrap the content in a SlideTransition from Offset(.08,0) to match the prototype exactly.

#### ConfirmSheet (destructive / neutral confirm) `DS-24`
- **[MINOR · tokens] Barrier and shadow colors follow the theme instead of the plum literals** `DS-24-F3`
  - Prototype: states.jsx:234 barrier 'rgba(42,19,32,.48)'; :240 shadow '0 -12px 32px rgba(42,19,32,.2)'
  - Flutter now: confirm_sheet.dart:27 `AppColors.plum900.withOpacity(0.48)` (male #2E2A26); sheetDecoration shadow plum700 .14 (app_theme.dart:44-50)
  - Fix: Decide on one approach. To match literally, use `const Color(0x7A2A1320)` for the barrier and the DS-03-F3 shadow; otherwise document the theme-aware choice.

#### ConfirmSheet (destructive / neutral confirm) `DS-24`
- **[MINOR · tokens] Title gets -0.22px tracking** `DS-24-F4`
  - Prototype: states.jsx:248 h2 23px lh 1.12, no letterSpacing
  - Flutter now: confirm_sheet.dart:75 `AppTextStyles.h3.copyWith(fontSize: 23, height: 1.12)`
  - Fix: Add `letterSpacing: 0`.

#### ConfirmSheet (destructive / neutral confirm) `DS-24`
- **[MINOR · layout] Bottom padding is 24 + inset instead of 34** `DS-24-F5`
  - Prototype: states.jsx:240 padding '18px 22px 34px'
  - Flutter now: confirm_sheet.dart:36-41 bottom `24 + MediaQuery.paddingOf(ctx).bottom`
  - Fix: `math.max(34.0, 24 + MediaQuery.paddingOf(ctx).bottom)` (after F1, so the inset no longer includes the tab bar).

#### ScreenHeader `DS-28`
- **[MINOR · tokens] Title gets -0.22px tracking** `DS-28-F1`
  - Prototype: states.jsx:419 h2 DM Serif 22 plum900 lh 1.1, no letterSpacing
  - Flutter now: screen_chrome.dart:58-61 `AppTextStyles.h3.copyWith(fontSize: titleSize, height: 1.1)` inherits -0.22
  - Fix: Add `letterSpacing: 0`.

#### ScreenHeader `DS-28`
- **[MINOR · layout] No 12px gap before the trailing slot** `DS-28-V1`
  - Prototype: states.jsx:415 `display: 'flex', alignItems: 'center', gap: 12`. The gap applies between the title block (:417) and `right` (:421).
  - Flutter now: screen_chrome.dart:77 `if (trailing != null) trailing!` directly after the Expanded title column, with no spacer. It is used with a trailing widget at notifications_page.dart:47.
  - Fix: `if (trailing != null) ...[const SizedBox(width: 12), trailing!],`

#### StickyBar `DS-29`
- **[MINOR · layout] Single child with no built-in row/gap, and different bottom padding** `DS-29-F1`
  - Prototype: states.jsx:431-432 `padding: '14px 22px 32px'`, `display: 'flex', gap: 10` (multiple buttons side by side)
  - Flutter now: screen_chrome.dart:132-151 takes `child`; padding bottom `14 + MediaQuery.paddingOf(context).bottom`
  - Fix: Accept `List<Widget> children` and build `Row(children: children.expand((w) => [Expanded(child: w), const SizedBox(width: 10)]).toList()..removeLast())`. Use bottom `math.max(32.0, 14 + inset)`.

#### SettingsRow `DS-30`
- **[MINOR · components] Missing `right` slot and gold tone; icon is required** `DS-30-F1`
  - Prototype: states.jsx:438 `SettingsRow({ icon, label, value, onTap, danger, tone, right, sub })`, tone 'gold' uses gold100/gold700 (:448-449, used at account-screens.jsx:108-109)
  - Flutter now: screen_chrome.dart:155-175 has `required this.icon` and no `tone` or `trailing` parameter
  - Fix: Add `final Widget? trailing; final SettingsTone tone;`, map gold to AppColors.gold100/gold700, and make icon nullable.

#### SettingsRow `DS-30`
- **[MINOR · tokens] Boxed variant uses profile-row internals** `DS-30-F2`
  - Prototype: states.jsx:442-458 gap 13, tile radius 11, label 14/600 ink, value 12.5 ink3, chevron 17 ink4
  - Flutter now: screen_chrome.dart:186 tile radius 10; :194 gap 14; :201-205 label body 15/w500; :221 value meta 13; :225 chevron 16 ink3 (the same internals are used for boxed at :230-243)
  - Fix: When `boxed`, use radius 11, gap 13, `AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)`, value fontSize 12.5, and chevron 17 ink4.

#### SettingsRow `DS-30`
- **[MINOR · states] Danger rows lose the chevron, and a ripple is used instead of row hover** `DS-30-F3`
  - Prototype: states.jsx:458 chevron shown when `onTap && !right` (danger too); :441 `.aiwa-row-hover` gives background #F0E8DC (states.jsx:16), with no ripple
  - Flutter now: screen_chrome.dart:223 chevron only when `!danger && onTap != null` (correct for the ProfileScreen row but not for boxed); :245 InkWell draws the Material ripple
  - Fix: In boxed mode show the chevron for danger rows too. Use `InkWell(splashFactory: NoSplash.splashFactory, highlightColor: AppColors.hover, …)`.

#### Interaction state classes (press / row-hover / focus ring) `DS-31`
- **[MINOR · interaction] Press scale exists only on AiwaButton** `DS-31-F1`
  - Prototype: prototype.html:41-42 `button:active:not(:disabled){transform:scale(.96)}` applies to <button> elements only: IconBtn (components.jsx:83), Chip (:135), TabBar items (:222), the SectionHeader action (:197) and the InlineBanner action (states.jsx:165). Div cards get only a transform transition (prototype.html:43) with no :active rule, and the [data-card] hover (:50-52) is unused.
  - Flutter now: Only aiwa_button.dart:114-117 (0.97) gives press feedback. review_page.dart:215 AnimatedScale is a selected-star state (0.94), not a press. 43 of the 44 `GestureDetector(` call sites in lib/ (all except aiwa_button.dart:118) have no press feedback, including aiwa_icon_button.dart:61, aiwa_chip.dart:37, shell_page.dart:123, section_header.dart:39 and screen_chrome.dart:358.
  - Fix: Create lib/shared/widgets/aiwa_pressable.dart: a StatefulWidget with AnimatedScale 0.96, 120ms and AppTheme.easeSoft, driven by onTapDown/Up/Cancel. Use it only in widgets that are <button>s in the kit: AiwaIconButton, AiwaChip, _TabItem, the SectionHeader action, the InlineBanner action, and the splash language buttons. Leave div-style cards and rows without a press scale.

#### Interaction state classes (press / row-hover / focus ring) `DS-31`
- **[MINOR · states] No keyboard focus ring and no button semantics** `DS-31-F2`
  - Prototype: states.jsx:17 `.aiwa-focusable:focus-visible{outline:2px solid #7E3A5C;outline-offset:2px}` on Toggle (:212), Pagination (:304-315) and OfflineBanner Retry (:139); README.md:123 'required for … WCAG pass'
  - Flutter now: grep finds no Focus, FocusableActionDetector, Semantics( or tooltip in lib/. GestureDetector-based AiwaButton/AiwaIconButton/AiwaChip are neither focusable nor announced as buttons.
  - Fix: In AiwaPressable use `FocusableActionDetector(onShowFocusHighlight: …, actions: {ActivateIntent: …})` and draw a 2px `AppColors.plum500` border with a 2px gap when focused. Wrap it in `Semantics(button: true, label: …)`, and require a semanticLabel on AiwaIconButton.

#### Interaction state classes (press / row-hover / focus ring) `DS-31`
- **[MINOR · states] Material ripple used where the prototype uses a hover tint** `DS-31-F3`
  - Prototype: states.jsx:16 `.aiwa-row-hover:hover{background:#F0E8DC !important}` with no ripple anywhere
  - Flutter now: screen_chrome.dart:245 and notifications_page.dart:207 use InkWell with the default M3 splash seeded from AppColors.plum700 (app_theme.dart:104-115)
  - Fix: Set `splashFactory: NoSplash.splashFactory` in AppTheme.light and use `highlightColor: AppColors.hover` on row InkWells.

#### Toast overlay `DS-32`
- **[MINOR · tokens] Text size, background, shadow and blur differ** `DS-32-F3`
  - Prototype: prototype.jsx:28-31,36 bg 'rgba(42,19,32,.96)', padding 12x16, shadow '0 12px 32px rgba(74,31,56,.3)', backdropFilter blur(8px), text 13/500 fontBody
  - Flutter now: app_theme.dart:186-190 bg AppColors.plum900.withOpacity(0.96) (male #2E2A26), text AppTextStyles.bodySm (14) w500 bone, default M3 elevation, no blur
  - Fix: Use `AppTextStyles.meta.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.bone)` and `BoxShadow(color: AppColors.plum700.withOpacity(.3), blurRadius: 32, offset: Offset(0,12))`, and wrap in BackdropFilter blur 8.

#### Toast overlay `DS-32`
- **[MINOR · interaction] Auto-dismiss is 4s (default) instead of 2.8s, with a different entrance** `DS-32-F4`
  - Prototype: prototype.jsx:22 `setTimeout(onClose, 2800)`; :30 `aiwa-toast 320ms cubic-bezier(.32,.72,0,1)` (opacity 0 to 1, translateY -10 to 0, prototype.html:26-29)
  - Flutter now: SnackBar default duration 4000ms and default slide-up; snackBarTheme sets no duration
  - Fix: In showAiwaToast, animate with a SlideTransition from Offset(0,-10/h) plus FadeTransition over AppTheme.dur3 with easeSoft, and remove the entry after 2800ms.

#### Toast overlay `DS-32`
- **[MINOR · states] The same toast is used for error messages** `DS-32-F5`
  - Prototype: The toast is only used for success confirmations (every setToast call in prototype.jsx is a success message). Errors use ValidatedInput / InlineBanner / ErrorState (states.jsx).
  - Flutter now: showSnackBar(Text(state.message)) for failures at avatar_gender_page.dart:77, otp_page.dart:103, phone_entry_page.dart:77, provider_verification_page.dart:55, booking_page.dart:117, review_page.dart:97
  - Fix: Route failures to an InlineBanner(tone: danger) or per-field errors, and keep showAiwaToast for success only (or add a danger variant with a triangle icon if a transient error is needed).

#### Screen transitions (push / pop / tab switch) `DS-33`
- **[MINOR · interaction] Tab switches have no animation (prototype slides the new tab root in)** `DS-33-F2`
  - Prototype: prototype.jsx:564-573 onTabChange calls setDirection('back') and then reset(). reset() (:556-560) calls setDirection('forward') in the same event, so the last update wins and the new tab root plays aiwa-slide-in (translateX 8% to 0) over 320ms cubic-bezier(.32,.72,0,1) (:730). The 'fade rather than slide' comment at :567 does not match what renders.
  - Flutter now: app_router.dart:151-176: all five ShellRoute children use NoTransitionPage, so the swap is instant.
  - Fix: Use the DS-33-F1 softDoor CustomTransitionPage for the five ShellRoute children too: SlideTransition from Offset(.08, 0) to Offset.zero with AppTheme.dur3 and AppTheme.easeSoft. Use ScaleTransition .98 to 1 only if design confirms the :567 comment is the intended behaviour.

#### Screen transitions (push / pop / tab switch) `DS-33`
- **[MINOR · interaction] Back navigation does not use the scale .98 to 1 reveal** `DS-33-F3`
  - Prototype: pop() sets direction 'back' (prototype.jsx:552-555), so the revealed screen plays aiwa-fade-in scale .98 to 1 over 320ms
  - Flutter now: The reverse of the platform push transition
  - Fix: In the softDoor transitionsBuilder, use `secondaryAnimation` to scale the underlying page from .98 to 1 as it is revealed (ScaleTransition driven by ReverseAnimation(secondaryAnimation)).

#### Wordmark / logo assets / app icon `DS-35`
- **[MINOR · tokens] Wordmark renders about 19% too large (size means font size, not box height)** `DS-35-F3`
  - Prototype: prototype.jsx:5-11 `Wordmark({ height = 56 })`: the SVG is 100 units high with text fontSize 84, so it renders about 47px text with a 6.7px dot (r6/100 x 56) at the text's right baseline
  - Flutter now: screen_chrome.dart:469-485 `fontSize: size`, dot `size * 0.14`; splash_page.dart:118-119 `AiwaWordmark(size: 56)` gives 56px text and a 7.8px dot
  - Fix: Treat the parameter as height: `final fs = height * 0.84;` then `letterSpacing: -fs * 2 / 84`, dot diameter `height * 0.12`, and wrap it in `SizedBox(height: height, width: height * 3.2)`.

#### Wordmark / logo assets / app icon `DS-35`
- **[MINOR · content] App display name and native launch background are unbranded** `DS-35-F4`
  - Prototype: Brand name 'AIWA' (Wordmark aria-label, prototype.jsx:8); the splash uses the plum700 to plum900 gradient (prototype.jsx:47)
  - Flutter now: android/app/src/main/AndroidManifest.xml:3 `android:label="aiwa_app"`; ios/Runner/Info.plist:10 'Aiwa App'; android/app/src/main/res/drawable/launch_background.xml uses `@android:color/white`
  - Fix: Set the label/CFBundleDisplayName to 'AIWA'. Use flutter_native_splash with color #2E2A26 (the male default) to avoid a white flash before SplashPage.

#### Wordmark / logo assets / app icon `DS-35`
- **[MINOR · layout] Wordmark dot is anchored to the text box bottom, not to the baseline** `DS-35-V1`
  - Prototype: prototype.jsx:9-10: the text baseline is y=74 and the dot is `<circle cx="307" cy="68" r="6">`, so the dot's bottom edge (68+6 = 74) sits exactly on the baseline after the final 'A'.
  - Flutter now: screen_chrome.dart:465-486 `Row(crossAxisAlignment: CrossAxisAlignment.end)` with the dot's `margin: EdgeInsets.only(left: size * 0.08, bottom: size * 0.1)` measured from the bottom of a height-1 Text box. That box extends below the baseline by DM Serif's descent share, so the dot's height depends on font metrics rather than the baseline (not verified on device).
  - Fix: Use `Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, ...)` and drop the bottom margin. A child with no baseline is placed with its bottom on the baseline, which matches the SVG. Combine this with the DS-35-F3 sizing (fs = height*0.84, dot = height*0.12).

#### GuestLockedScreen (shared guest gate) `DS-36`
- **[MINOR · content] Per-tab titles, bodies and icons differ from the prototype** `DS-36-F2`
  - Prototype: prototype.jsx:699 'See your bookings' / 'Sign in to view and track your bookings.' / calendar-check; :707 'Save your favorites' / 'Sign in to save providers you love and book them faster next time.' / heart; :710 'Your profile' / 'Sign in to manage your account, addresses, and notifications.' / user
  - Flutter now: my_bookings_page.dart:40-43 'Your bookings live here' / 'Sign in to book providers, track them on the way, and see your history.'; saved_page.dart:37-40 'Keep your favorites' / 'Sign in to save providers and book them again in one tap.'; profile_page.dart:33-36 'Make AIWA yours' / 'Sign in to manage your details, notifications and bookings.'
  - Fix: Replace the title/body strings at those three call sites with the prototype copy (the icons already match in meaning).

#### GuestLockedScreen (shared guest gate) `DS-36`
- **[MINOR · tokens] Title gets -0.26px tracking** `DS-36-F3`
  - Prototype: customer-extras-2.jsx:19 h2 DM Serif 24 lh 1.1, no letterSpacing
  - Flutter now: guest_locked_view.dart:45 `AppTextStyles.h2.copyWith(fontSize: 24, height: 1.1)` inherits -0.26
  - Fix: Add `letterSpacing: 0`.

#### RTL / Arabic localization `DS-RTL`
- **[MINOR · tokens] No Arabic font fallback (IBM Plex Sans Arabic / Markazi Text) in the text styles** `DS-RTL-F1`
  - Prototype: tokens/colors_and_type.css:96-101 add Markazi Text / IBM Plex Sans Arabic to --font-display / --font-body, and :277-286 define RTL headings (Markazi 500, letter-spacing 0). The rendered prototype does not apply them: fontBody/fontDisp (components.jsx:17-18) contain no Arabic family, so Arabic body text such as the 'العربية' language value (account-screens.jsx:61) falls back to the system font. Markazi is used only through explicit inline styles at prototype.jsx:73 (splash button) and flow-screens.jsx:135 (preferences option).
  - Flutter now: app_text_styles.dart:131-169: _serif/_sans set no fontFamilyFallback. Only splash_page.dart:244-261 uses GoogleFonts.markaziText. IBM Plex Sans Arabic appears nowhere in lib/, so 'العربية' in profile (profile_page.dart:73-75) renders in the OS fallback font (as it does in the prototype).
  - Fix: In app_text_styles.dart, add `fontFamilyFallback: aiwaUseGoogleFonts ? [GoogleFonts.ibmPlexSansArabic().fontFamily!] : const ['IBM Plex Sans Arabic']` to _sans and the Markazi equivalent to _serif. Add `AppTextStyles.arabicDisplay` (Markazi w500, letterSpacing 0) and use it in splash_page.dart instead of the local _arabicStyle.

#### RTL / Arabic localization `DS-RTL`
- **[MINOR · rtl] No localization infrastructure for the promised bilingual app** `DS-RTL-F3`
  - Prototype: README.md:4 'bilingual (EN/AR)'. The prototype UI itself is English-only with no dir switching (see notes).
  - Flutter now: app.dart:81-82 `locale: const Locale('en'), supportedLocales: [en, ar]` with no localizationsDelegates. flutter_localizations is unused (pubspec.yaml:12-13). There are no .arb/l10n files and no Directionality. All copy is hard-coded English (e.g. guest_locked_view.dart:41, empty_state.dart:129-130, confirm_sheet.dart:17-18).
  - Fix: Enable gen-l10n (l10n.yaml + lib/l10n/app_en.arb/app_ar.arb), add `localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]`, drive `locale` from the stored preference, and replace EdgeInsets.fromLTRB/left/right with EdgeInsetsDirectional in shared widgets.

#### Shell back behaviour (pop / root no-op) `DS-V01`
- **[MINOR · interaction] System back on a tab root closes the app; the prototype's pop() does nothing on a one-entry stack** `DS-V01-F1`
  - Prototype: prototype.jsx:552-555 `setStack(s => s.length > 1 ? s.slice(0, -1) : s)`. Tab switches and the end of onboarding call reset() (:556-560, :564-573, :608), so each tab root is a one-entry stack and back does nothing there. :575-580 binds Escape/Backspace to pop() in the web demo.
  - Flutter now: Tab roots are entered with context.go (shell_page.dart:94, splash_page.dart:59, :71-75), which replaces the whole stack. There is no PopScope/WillPopScope/onPopInvoked anywhere in lib/ (grep), so Android back on /app/home, /app/bookings, /app/saved, /app/profile or /app/search falls through to SystemNavigator.pop and exits the app.
  - Fix: In shell_page.dart, wrap the Scaffold in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (didPop) return; final loc = GoRouterState.of(context).uri.path; if (loc != AppRoutes.home) context.go(AppRoutes.home); })`. Tab roots then return to Home instead of exiting. Whether Home itself exits is a platform-convention decision to confirm with design. Do not copy the prototype's Backspace listener: it pops even while the user is typing and exists only for the desktop demo.

#### Cross-cutting `-`
- **[MINOR · tokens] Colors are centralized; only 6 raw Colors.white literals remain** `DS-C1`
  - Prototype: JSX itself uses white-alpha literals, e.g. 'rgba(255,255,255,.85)' (components.jsx:80) and 'rgba(255,255,255,.16)' / '.18' (auth-screens.jsx:721)
  - Flutter now: 'Color(0x' outside lib/core/theme: 0. 'Colors.' (excluding transparent and AppColors): 6, all Colors.white.withOpacity: provider_pending_page.dart 4 (:47 .16, :49 .18, :160 .08, :162 .12), role_choice_page.dart 1 (:134 .18), aiwa_icon_button.dart 1 (:44 .85). None contradict tokens.
  - Fix: Optionally add `static Color whiteA(double a) => AppColors.paper.withValues(alpha: a);` in app_colors.dart and replace the 6 literals so all color goes through the theme.

#### Cross-cutting `-`
- **[MINOR · tokens] 116 fontSize overrides (all copyWith on AppTextStyles) with off-scale sizes** `DS-C2`
  - Prototype: Token scale 48/32/26/20/17/16/14/13/11 (css:104-112). The JSX also uses off-scale 11.5 / 12.5 / 13.5 (e.g. states.jsx:98, 138, 202).
  - Flutter now: 116 'fontSize:' in 35 files outside lib/core/theme. Top files: provider_detail_page.dart 10, dashboard_page.dart 9, booking_page.dart 9, screen_chrome.dart 7, provider_business_page.dart 6, provider_card.dart 5, my_bookings_page.dart 5. Values: 12 x19, 11.5 x17, 14 x11, 13.5 x7, 10 x6, 20 x6, 12.5 x4, 9 x1 (provider_list_item.dart:87 EyebrowLabel 9px), 54 (avatar_gender_page.dart:129), 38 (provider_detail_page.dart:412). Only splash_page.dart:254 builds a raw TextStyle with a size (test fallback). 'FontWeight.' overrides: 25 (screen_chrome 3, provider_detail_page 3, provider_card 3, notifications_page 2, splash_page 2, provider_pending_page 2, phone_entry_page 2, …). 'TextStyle(' outside theme: 5 (phone_entry_page.dart:128,136; provider_pending_page.dart:84; booking_confirmed_page.dart:68 are TextSpan color/weight overrides that inherit the family). 'GoogleFonts.' outside theme: 1 (splash_page.dart:247 markaziText).
  - Fix: Add named styles for the recurring JSX sizes (e.g. `static TextStyle get caption => _sans(fontSize: 11.5, height: 1.45, color: AppColors.ink3);`, `bodyXs` 12.5, `bodySmPlus` 13.5) plus `arabicDisplay` (Markazi) in app_text_styles.dart, and replace copyWith(fontSize:) chains. Check the 9px eyebrow against its screen JSX.

#### Cross-cutting `-`
- **[MINOR · tokens] Radii are mostly inline literals: 66 BorderRadius.circular calls outside the theme, only 14 via AppTheme** `DS-C3`
  - Prototype: Tokens are r-xs 4 / sm 8 / md 12 / lg 18 / xl 24 / pill 999 (css:139-144), plus inputs 14 (README.md:37). The JSX literals themselves are mostly 14, 18, 12, 10 and 16.
  - Flutter now: There are 52 non-token radii outside lib/core/theme: 50 numeric literals plus provider_list_item.dart:36 (discover ? 18 : 16) and loading_shimmer.dart:29 (variable). The literals are 14 x16, 12 x10, 2 x5, 16 x4 (booking_page.dart:386, profile_page.dart:259, dashboard_page.dart:417, avatar_gender_page.dart:203), 10 x4 (screen_chrome.dart:186, booking_page.dart:288, my_bookings_page.dart:536, provider_business_page.dart:281), 999 x3 (status_pill.dart:19, provider_card.dart:61, saved_page.dart:245), 20 x2 (role_choice_page.dart:118, auth_choice_page.dart:186), 22 x2 (home_page.dart:254, provider_pending_page.dart:48), 6 x2, 5 x1 and 18 x1 (booking_confirmed_page.dart:93). provider_detail_page.dart:316 also has Radius.circular(28). Only AppTheme.radiusPill (7) and radiusLg (7) are referenced. Top files by raw literals: booking_page.dart 7, provider_business_page.dart 5, then screen_chrome.dart, profile_page.dart and provider_verification_page.dart with 3 each.
  - Fix: Add `radiusInput = 14`, `radiusTile = 10`, `radius16 = 16`, `radius20 = 20` and `radius22 = 22` to AppTheme (mirroring the JSX literals) and replace the inline values. Use AppTheme.radiusPill for the three 999 literals and AppTheme.radiusLg at booking_confirmed_page.dart:93.

#### Cross-cutting `-`
- **[MINOR · interaction] Press-scale feedback exists only on AiwaButton** `DS-C6`
  - Prototype: prototype.html:41-42 `button:active:not(:disabled){transform:scale(.96)}` with a 120ms soft transition applies to <button> elements only (IconBtn, Chip, TabBar items, SectionHeader/InlineBanner actions). Div cards have no :active rule (prototype.html:43 only sets a transition).
  - Flutter now: AnimatedScale press feedback exists only at aiwa_button.dart:114-117 (0.97); review_page.dart:215 is a selection-state scale. 43 of the 44 `GestureDetector(` call sites in lib/ have no press feedback, and the ones that matter are the kit-button equivalents (aiwa_icon_button.dart:61, aiwa_chip.dart:37, shell_page.dart:123, section_header.dart:39, screen_chrome.dart:358).
  - Fix: See DS-31-F1: add lib/shared/widgets/aiwa_pressable.dart (scale 0.96, 120ms, easeSoft) and use it in the kit-button equivalents only, not in card rows.

#### Cross-cutting `-`
- **[MINOR · states] No keyboard focus ring or semantics** `DS-C7`
  - Prototype: states.jsx:17 `.aiwa-focusable:focus-visible{outline:2px solid #7E3A5C;outline-offset:2px}`; README.md:123
  - Flutter now: grep finds no Focus(, FocusableActionDetector, Semantics( or tooltip in lib/. GestureDetector-based shared controls cannot be focused and are not exposed as buttons to screen readers.
  - Fix: See DS-31-F2: use FocusableActionDetector + a 2px AppColors.plum500 ring in AiwaPressable, and wrap it in Semantics(button: true, label: …).

#### Cross-cutting `-`
- **[MINOR · tokens] Hard-coded animation durations are off the motion scale** `DS-C8`
  - Prototype: Motion scale 120/200/320/480ms (css:171-174)
  - Flutter now: sign_in_page.dart:193 150ms; review_page.dart:217 180ms; account_setup_page.dart:184 literal 200ms (should be AppTheme.dur2); aiwa_button.dart:116 literal 120ms (no dur1 token); splash_page.dart:28 900ms
  - Fix: Snap to AppTheme.dur1 (120) or dur2 (200) once DS-04-F1 adds the missing constants, and replace the literals.

#### Cross-cutting `-`
- **[MINOR · states] Error feedback goes through the success-style toast** `DS-C10`
  - Prototype: The toast only confirms successes (prototype.jsx:20-39, success500 check). Errors appear inline via ValidatedInput / InlineBanner / ErrorState (states.jsx).
  - Flutter now: `showSnackBar(SnackBar(content: Text(state.message)))` for failures at avatar_gender_page.dart:77, otp_page.dart:103, phone_entry_page.dart:77, provider_verification_page.dart:55, booking_page.dart:117 and review_page.dart:97
  - Fix: Show failures in InlineBanner(tone: BannerTone.danger) near the action, or as per-field errors, and keep the toast for success (DS-32).

#### Cross-cutting `-`
- **[MINOR · components] Material Icons are used app-wide instead of Lucide** `DS-C11`
  - Prototype: README.md:49 'Icons: Lucide (24px stroke, 2px weight)'; every <Icon name=…> in the JSX
  - Flutter now: Every icon is Icons.* (no Lucide dependency in pubspec.yaml:9-70)
  - Fix: See DS-05-F1: add lucide_icons_flutter and an AiwaIcons alias file, then migrate the shared widgets first.
