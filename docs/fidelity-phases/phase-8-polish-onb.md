# Polish backlog — onb (minor findings)

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · layout] Bio counter shares a row with the hint; textarea height differs** `ONB-12-F2`
  - Prototype: auth-screens.jsx:563 textarea `height: 84`, then :565 `<div style={{ fontSize: 11, color: aiwa.ink3, marginTop: 4, textAlign: 'right' }}>{bio.length}/240</div>`; the Field hint renders on its own line below (auth-screens.jsx:27, marginTop 5)
  - Flutter now: provider_business_page.dart:192 `maxLines: 3` (3 x 15 x 1.5 + 28 padding = about 95px); aiwa_text_field.dart:152-171 puts the hint (Expanded) and counter in one Row under the field
  - Fix: In provider_business_page.dart pass `hint: null, showCounter: false`, then add `Padding(padding: EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerRight, child: Text('${_bioCtrl.text.length}/240', style: AppTextStyles.micro)))`, SizedBox(height: 5) and the hint Text (micro 11.5). For the 84px height, add `bool expands = false` and `TextStyle? textStyle` params to AiwaTextField (pass `expands` to TextFormField, forcing maxLines/minLines to null when true) and wrap the bio field's input in `SizedBox(height: 84)`.

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · layout] Category tiles are about 18px taller than in the prototype** `ONB-12-F3`
  - Prototype: auth-screens.jsx:574-575 `padding: '12px 4px', borderRadius: 12` gives a natural height of about 62px (12 + icon 18 + gap 6 + label + 12)
  - Flutter now: provider_business_page.dart:207 `childAspectRatio: 0.95`, about 80px tall on a 375px-wide screen
  - Fix: Use `childAspectRatio: 1.2`, or replace GridView with Rows of Expanded tiles padded `EdgeInsets.symmetric(vertical: 12, horizontal: 4)`.

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · tokens] Bio text size 15 instead of 14** `ONB-12-F4`
  - Prototype: auth-screens.jsx:563 `fontFamily: fontBody, fontSize: 14, color: aiwa.ink`
  - Flutter now: aiwa_text_field.dart:96 `style: AppTextStyles.body.copyWith(color: AppColors.ink)` (Plus Jakarta 15)
  - Fix: Add an optional `TextStyle? textStyle` to AiwaTextField and pass `AppTextStyles.bodySm.copyWith(color: AppColors.ink)` for the bio.

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · components] 'Use GPS' rendered as a Material TextButton** `ONB-12-F5`
  - Prototype: auth-screens.jsx:591 `<button ... style={{ background: 'transparent', border: 0, color: aiwa.plum700, fontSize: 12, fontWeight: 600 }}>Use GPS</button>`
  - Flutter now: provider_business_page.dart:256-262 `suffixIcon: TextButton(onPressed: ..., child: Text('Use GPS', style: AppTextStyles.labelSm.copyWith(color: AppColors.plum700)))`, which adds a 64x40 minimum size, padding and an ink ripple
  - Fix: `TextButton(style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 14), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, splashFactory: NoSplash.splashFactory), ...)`

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · content] Lucide icons swapped for different Material glyphs** `ONB-12-F6`
  - Prototype: auth-screens.jsx:482-489 `scissors`, `hand`, `leaf`, `brush`, `eye`, `droplets`, `hand-heart`, `sparkles`; :512 `store`; :517 `user`; :589 `map-pin`
  - Flutter now: provider_business_page.dart:31-38 Icons.content_cut_rounded, back_hand_outlined, spa_outlined, brush_outlined, visibility_outlined, water_drop_outlined, volunteer_activism_outlined, auto_awesome_outlined; :100 storefront_outlined; :110 person_outline_rounded; :255 location_on_outlined
  - Fix: To match exactly, add a Lucide icon package (e.g. lucide_icons_flutter) and use LucideIcons.hand, .handHeart, .leaf, .store, .user, .mapPin. Otherwise accept the Material equivalents as a documented deviation.

#### Provider business — 'Set up your studio' (Individual default) `ONB-12`
- **[MINOR · layout] Step scaffold top offset and sticky-bar bottom padding differ (also ONB-17)** `ONB-12-V1`
  - Prototype: auth-screens.jsx:504 root `padding: '70px 24px 120px'` and :613 sticky bar `padding: '14px 22px 32px'`, measured from the frame edge. The status bar overlay is 62px (ios-frame.jsx:14) and the home indicator 34px (ios-frame.jsx:220), so the back button sits 8px below the status bar and the bar's bottom padding is 32px from the edge. ProviderVerificationScreen uses the same values (auth-screens.jsx:676, :702).
  - Flutter now: step_header.dart:96 `EdgeInsets.fromLTRB(24, insets.top + 18, 24, 16)` puts the back button 18px below the status bar, and :109 `EdgeInsets.fromLTRB(22, 14, 22, 14 + insets.bottom)` gives about 48px bottom padding on a 34px-inset iPhone.
  - Fix: In AuthStepScaffold (step_header.dart:96, :109) use `insets.top + 8` for the scroll top padding and `EdgeInsets.fromLTRB(22, 14, 22, math.max(32.0, insets.bottom))` for the sticky bar. This is shared with the other auth steps, so confirm with the AUTH audit before changing it.

#### Provider business — Shop / salon variant (staff members) `ONB-13`
- **[MINOR · components] Staff remove control is a 48dp IconButton with an 18px icon** `ONB-13-F1`
  - Prototype: auth-screens.jsx:542-543 `<button ... style={{ background: 'transparent', border: 0, color: aiwa.danger700, cursor: 'pointer', padding: 8 }}><Icon name="x" size={16} /></button>`
  - Flutter now: provider_business_page.dart:156-160 `IconButton(icon: Icon(Icons.close_rounded, size: 18, color: AppColors.danger700), ...)` with default 48x48 constraints and a ripple
  - Fix: `GestureDetector(onTap: remove, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 16, color: AppColors.danger700)))`

#### Provider business — Shop / salon variant (staff members) `ONB-13`
- **[MINOR · components] 'Add staff member' border is solid, not dashed** `ONB-13-F2`
  - Prototype: auth-screens.jsx:550 `border: `1.5px dashed ${aiwa.divider}``
  - Flutter now: provider_business_page.dart:388-390 `border: Border.all(color: AppColors.divider, width: 1.5)`; the class comment at :375 admits it is only 'Dashed-looking'
  - Fix: Draw the border with a small CustomPainter (dash 5 / gap 4 along a 12-radius RRect via PathMetric.extractPath) and reuse it for ONB-14 and ONB-15.

#### Provider business — GPS status card (locked / no GPS) `ONB-14`
- **[MINOR · states] Initial GPS state inverted (No GPS instead of GPS locked)** `ONB-14-F1`
  - Prototype: auth-screens.jsx:497 `const [hasLocation, setHasLocation] = useStateA(true);`
  - Flutter now: provider_business_page.dart:27 `bool _hasLocation = false;`
  - Fix: Start with the locked state by fetching the position in initState (see F3). Or set `_hasLocation = true` if the mock is kept.

#### Provider business — GPS status card (locked / no GPS) `ONB-14`
- **[MINOR · components] GPS card border is solid, not dashed** `ONB-14-F2`
  - Prototype: auth-screens.jsx:597 `border: `1px dashed ${aiwa.divider}`, borderRadius: 12`
  - Flutter now: provider_business_page.dart:270 `border: Border.all(color: AppColors.divider),`
  - Fix: Use the shared dashed-border painter from ONB-13-F2 (1px, radius 12).

#### UploadSlot — empty (tap to upload) `ONB-15`
- **[MINOR · components] Empty slot border solid instead of dashed** `ONB-15-F2`
  - Prototype: auth-screens.jsx:640 `border: `1.5px ${value ? 'solid' : 'dashed'} ${value ? aiwa.plum700 : aiwa.divider}``
  - Flutter now: provider_verification_page.dart:174 `border: Border.all(color: AppColors.divider, width: 1.5)`
  - Fix: Use the shared dashed-border painter (1.5px, radius 14) for the empty state.

#### UploadSlot — empty (tap to upload) `ONB-15`
- **[MINOR · layout] Inner gaps differ (8 vs 12 before the upload icon; 3 vs 2 under the label)** `ONB-15-F3`
  - Prototype: auth-screens.jsx:641 `gap: 12` (applies between tile, text and upload icon) and :652 `marginTop: 2`
  - Flutter now: provider_verification_page.dart:207 `const SizedBox(width: 8)` and :196 `const SizedBox(height: 3)`
  - Fix: Change them to SizedBox(width: 12) and SizedBox(height: 2).

#### UploadSlot — uploaded state (photo preview, tap to replace) `ONB-16`
- **[MINOR · tokens] Caption scrim gradient differs** `ONB-16-F2`
  - Prototype: auth-screens.jsx:658 `background: 'linear-gradient(to top, rgba(42,19,32,.7), transparent 60%)'`
  - Flutter now: provider_verification_page.dart:145 `colors: [AppColors.plum500, AppColors.plum900]`, opaque top to bottom (male #5C544D -> #2E2A26)
  - Fix: Add a foreground layer: `Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xB32A1320), Color(0x002A1320)], stops: [0, .6])))`

#### UploadSlot — uploaded state (photo preview, tap to replace) `ONB-16`
- **[MINOR · content] Uploaded caption icon is filled; Lucide check-circle is an outline** `ONB-16-V1`
  - Prototype: auth-screens.jsx:660 `<Icon name="check-circle" size={14} color={aiwa.bone} />` (outline circle with check)
  - Flutter now: provider_verification_page.dart:152 `Icon(Icons.check_circle_rounded, size: 14, color: AppColors.bone)` (solid filled disc)
  - Fix: Use `Icons.check_circle_outline_rounded`, the glyph provider_pending_page.dart:99 already uses for the same Lucide icon.

#### Provider verification — 'Verify your identity' `ONB-17`
- **[MINOR · components] Private-docs note padding and icon gap differ (InlineBanner)** `ONB-17-F3`
  - Prototype: auth-screens.jsx:697 `padding: 14, background: aiwa.plum100, borderRadius: 14 ... gap: 8`
  - Flutter now: provider_verification_page.dart:105-110 `InlineBanner(tone: BannerTone.plum, ...)`; screen_chrome.dart:318 `EdgeInsets.symmetric(horizontal: 13, vertical: 11)` and :330 `SizedBox(width: 10)`
  - Fix: Replace it with a local Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.plum100, borderRadius: BorderRadius.circular(14))) holding a Row with the icon, SizedBox(width: 8) and Expanded text.

#### Provider verification — 'Verify your identity' `ONB-17`
- **[MINOR · tokens] Private-docs note text 12.5px instead of 12px** `ONB-17-F4`
  - Prototype: auth-screens.jsx:697 `fontSize: 12, color: aiwa.plum700, lineHeight: 1.5`
  - Flutter now: screen_chrome.dart:348-351 `AppTextStyles.micro.copyWith(fontSize: 12.5, color: fg, height: 1.5)`
  - Fix: Use `AppTextStyles.micro.copyWith(fontSize: 12, color: AppColors.plum700, height: 1.5)` in the local note.

#### Provider pending — 'We're reviewing your documents.' `ONB-18`
- **[MINOR · tokens] Glow uses the theme rose300 in a 340px circle instead of the full-screen #E7BAB6 radial** `ONB-18-F2`
  - Prototype: auth-screens.jsx:718 `background: 'radial-gradient(circle at 30% 25%, rgba(231,186,182,.45), transparent 60%)'` (hardcoded literal over the whole screen)
  - Flutter now: provider_pending_page.dart:23-31 `Positioned(left: -60, top: 40, child: AiwaGlow(size: 340, color: AppColors.rose300, opacity: 0.4))` (male #B5A898, female #E6BAB0)
  - Fix: `Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(-0.4, -0.5), radius: 0.9, colors: [Color(0x73E7BAB6), Color(0x00E7BAB6)], stops: [0, .6]))))`. Keep AppColors.rose300 only if the team intentionally departs from the literal.

#### Provider pending — 'We're reviewing your documents.' `ONB-18`
- **[MINOR · components] Icon tile missing the 8px backdrop blur** `ONB-18-F3`
  - Prototype: auth-screens.jsx:721 `background: 'rgba(255,255,255,.16)' ... backdropFilter: 'blur(8px)', border: '1px solid rgba(255,255,255,.18)'`
  - Flutter now: provider_pending_page.dart:43-50 Container with white .16 fill and white .18 border, no BackdropFilter
  - Fix: Wrap it in `ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: <existing container>))`.

#### Provider pending — 'We're reviewing your documents.' `ONB-18`
- **[MINOR · content] Hourglass glyph differs** `ONB-18-F4`
  - Prototype: auth-screens.jsx:722 `<Icon name="hourglass" size={34} />` and :736 `icon: 'hourglass'`
  - Flutter now: provider_pending_page.dart:52 and :111 `Icons.hourglass_top_rounded`
  - Fix: Use `Icons.hourglass_empty_rounded` (closest outline) or LucideIcons.hourglass.

#### Provider pending — 'We're reviewing your documents.' `ONB-18`
- **[MINOR · layout] Footnote gap and bottom padding differ (top padding matches)** `ONB-18-F5`
  - Prototype: auth-screens.jsx:717 `padding: '90px 28px 40px'` measured from the frame edge. The status bar is 62px (ios-frame.jsx:14) and the home indicator 34px (ios-frame.jsx:220), so content starts 28px below the status bar and the caption ends 40px above the bottom edge. :746 `gap: 10` plus the caption `margin: '4px 0 0'` (:750) makes 14px above the footnote.
  - Flutter now: provider_pending_page.dart:33-38 `EdgeInsets.fromLTRB(28, insets.top + 28, 28, insets.bottom + 28)`: the top matches, but the bottom is about 62px on a 34px-inset iPhone vs 40. :123 has `const SizedBox(height: 10)`.
  - Fix: Keep `insets.top + 28`. Change the bottom to `math.max(40.0, insets.bottom + 6)` (import 'dart:math' as math) and the gap above the footnote to `const SizedBox(height: 14)`.

#### Provider pending — 'We're reviewing your documents.' `ONB-18`
- **[MINOR · responsive] Fixed Column with Spacers overflows on short screens or large text** `ONB-18-F6`
  - Prototype: prototype.jsx:729 the screen wrapper is `overflow: 'auto'`, so the pending content can scroll
  - Flutter now: provider_pending_page.dart:39-134 a non-scrollable Column with two Spacer()s; about 560dp of content plus insets gives a RenderFlex overflow below about 640dp height or at textScale 1.3
  - Fix: Wrap it in `LayoutBuilder` -> `SingleChildScrollView` -> `ConstrainedBox(minHeight: constraints.maxHeight)` -> `IntrinsicHeight(child: Column(...))` so the Spacers still work.
