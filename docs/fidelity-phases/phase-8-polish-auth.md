# Polish backlog — auth (minor findings)

#### Wordmark (AIWA serif logotype + dot) `AUTH-02`
- **[MINOR · tokens] Wordmark glyphs are about 19% too large** `AUTH-02-F1`
  - Prototype: prototype.jsx:6-9: fontSize 84 inside a 100-unit-tall viewBox rendered at height 56, so the glyphs are 84x0.56 ≈ 47px.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart:469-476 `fontSize: size` gives 56px glyphs at size 56.
  - Fix: In AiwaWordmark use `fontSize: size * 0.84, letterSpacing: -2 * size / 100`.

#### Wordmark (AIWA serif logotype + dot) `AUTH-02`
- **[MINOR · layout] Dot size and position differ from the SVG** `AUTH-02-F2`
  - Prototype: prototype.jsx:10 `<circle cx="307" cy="68" r="6"/>`. That is a 6.7px dot at x=307/320 of a 3.2×height box, with its centre 6 units above the text baseline (y=74).
  - Flutter now: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart:478-485 dot `size * 0.14` (7.8px), `margin: EdgeInsets.only(left: size * 0.08, bottom: size * 0.1)`, placed right after the text.
  - Fix: Lay it out like the SVG: `SizedBox(width: size*3.2, height: size, child: Stack(children: [Positioned(left: 0, top: 0, child: Text('AIWA', ...fontSize: size*0.84)), Positioned(left: size*3.01, top: size*0.62, child: Container(width: size*0.12, height: size*0.12, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)))]))`.

#### Role choice - How will you be using AIWA? `AUTH-04`
- **[MINOR · components] Selected check icon is a filled Material glyph instead of an outline** `AUTH-04-F1`
  - Prototype: auth-screens.jsx:136 `<Icon name="check-circle" size={20} color={aiwa.bone} />` (Lucide outline).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/role_choice_page.dart:169-173 `Icons.check_circle_rounded` (filled disc).
  - Fix: Use `Icons.check_circle_outline_rounded` (size 20, AppColors.bone).

#### Auth choice - Create account vs I already have an account (customer & provider copy) `AUTH-05`
- **[MINOR · components] Glass back button is missing the backdrop blur** `AUTH-05-F2`
  - Prototype: components.jsx:80 glass: `background: 'rgba(255,255,255,.85)', backdropFilter: 'blur(8px)', border: '1px solid rgba(231,221,208,.7)'`.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_icon_button.dart:43-47 glass = `Colors.white.withOpacity(0.85)` with border `AppColors.divider.withOpacity(0.7)`, and no BackdropFilter.
  - Fix: For the glass variant, wrap the Container in `ClipOval(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: ...))`.

#### Auth choice - Create account vs I already have an account (customer & provider copy) `AUTH-05`
- **[MINOR · responsive] Hero half stays pinned while the cards scroll** `AUTH-05-F3`
  - Prototype: auth-screens.jsx:779-787: the hero is `position: 'absolute', inset: '0 0 50% 0'` inside the scrolling screen div, so it scrolls with the cards.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/auth_choice_page.dart:38-44 `Positioned(top: 0, left: 0, right: 0, height: size.height * 0.5, ...)` sits outside the SingleChildScrollView (:66). On short screens the cards scroll over a fixed hero.
  - Fix: Move the gradient into the scroll view, e.g. a Stack inside the SingleChildScrollView whose first child is the hero sized to half the viewport, so it scrolls together with the content.

#### Sign in - phone mode `AUTH-06`
- **[MINOR · interaction] 'Create an account' keeps Sign in on the back stack** `AUTH-06-F3`
  - Prototype: prototype.jsx:626 `onSwitchToSignUp={() => { reset('phone-entry'); }}` replaces the stack.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:94-97 `context.push(AppRoutes.phoneEntry, extra: {'role': widget.role})`. Back returns to Sign in, and SignInPage's AuthAuthenticated listener (:65-70) stays active through registration (see CF-03).
  - Fix: Use `context.pushReplacement(AppRoutes.phoneEntry, extra: {'role': widget.role})`.

#### Sign in - phone mode `AUTH-06`
- **[MINOR · components] Password eye toggle is an 18px Material IconButton** `AUTH-06-F4`
  - Prototype: auth-screens.jsx:934-936 plain button with `padding: 4` and `<Icon name={showPass ? 'eye-off' : 'eye'} size={16} />` in ink3.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:163-172 `IconButton(icon: Icon(..., size: 18, color: AppColors.ink3), ...)` with the default 48px tap box.
  - Fix: `IconButton(padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: AppColors.ink3), onPressed: ...)`

#### Sign in - phone mode `AUTH-06`
- **[MINOR · interaction] 'Remember me' has no effect** `AUTH-06-F5`
  - Prototype: auth-screens.jsx:875 `onSignIn({ identifier, mode, password, remember, role })` passes the flag along.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:31 `bool _remember = true;` is toggled at :188, but _submit (:53-59) and AuthLoginEvent never use it.
  - Fix: Add `remember` to AuthLoginEvent and skip persisting the refresh token in SecureStorage when it is false, or remove the checkbox with design sign-off.

#### Sign in - phone mode `AUTH-06`
- **[MINOR · layout] Gap between Password and the Remember-me row is 14px instead of 16px** `AUTH-06-V1`
  - Prototype: auth-screens.jsx:21 Field `marginBottom: 14` plus :948 remember row `marginTop: 2` = 16px when there is no error.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:184 `const SizedBox(height: 14)` before the Remember-me Row.
  - Fix: Use `SizedBox(height: _error == null ? 16 : 10)` at :184, together with a 14px gap above the banner (AUTH-08-F3).

#### Sign in - email mode `AUTH-07`
- **[MINOR · states] Autofocused email field opens with a plum700 focus ring** `AUTH-07-V1`
  - Prototype: auth-screens.jsx:922 `<TextInput ... type="email" icon="mail" autoFocus />`. The TextInput border stays `1.5px solid ${aiwa.divider}` (:39, male #D8CFC2 / female #EFDCD6) with `outline: 0` (:50), so the focused field looks idle.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:153 `autoFocus: true`, and Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:119-121 `focusedBorder: AppTheme.inputBorder(... AppColors.plum700)` (male #2E2A26 / female #6B3A3A). Switching to Email immediately draws a dark ring. The shared mode toggle above it also lacks the 4px segment gap (AUTH-10-F1).
  - Fix: Apply the AUTH-25-F1 fix (focusedBorder = AppColors.divider, or a design-approved focus style). AUTH-10-F1 fixes the toggle.

#### Sign in - wrong credentials error `AUTH-08`
- **[MINOR · components] Uses InlineBanner geometry instead of the compact error box** `AUTH-08-F2`
  - Prototype: auth-screens.jsx:942-943 `padding: '10px 12px', background: aiwa.danger100, borderRadius: 10, fontSize: 12.5, ... gap: 8` with `<Icon name="alert-circle" size={14} />`.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:178-182 `InlineBanner(tone: BannerTone.danger, icon: Icons.error_outline_rounded, body: _error)`, which renders with padding 13x11, radius 14, icon 16 and gap 10 (screen_chrome.dart:317-330).
  - Fix: Add a `compact` flag to InlineBanner (padding h12/v10, radius 10, icon 14, gap 8) and pass `compact: true` here.

#### Sign in - wrong credentials error `AUTH-08`
- **[MINOR · layout] Spacing around the error box is off** `AUTH-08-F3`
  - Prototype: The Password Field's marginBottom 14 sits above the box (auth-screens.jsx:21). The box has marginBottom 8 and the remember row marginTop 2 (:942, :948), so 14px above and 10px below.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:177 `SizedBox(height: 12)` above and :184 `SizedBox(height: 14)` below.
  - Fix: Use 14 above and 10 below the banner (and 16 before the remember row when there is no error).

#### Phone entry - phone mode (sign-up step 1) `AUTH-10`
- **[MINOR · components] Phone/Email toggle segments have no 4px gap between them** `AUTH-10-F1`
  - Prototype: auth-screens.jsx:180 track `padding: 4, gap: 4`; :183 segment `padding: '9px 14px'` with no lineHeight, so the 13px label sits in a browser-normal (~16px) line box and each segment is ~34px tall.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart:142-151: a Row of two Expanded segments with no spacing between them. `EdgeInsets.symmetric(vertical: 10)` around AppTextStyles.label (13px, height 1) gives ~33px, which already matches the height.
  - Fix: In IdentifierModeToggle, insert `const SizedBox(width: 4)` between the two segments (e.g. `children: [seg('phone'), const SizedBox(width: 4), seg('email')]`). Keep vertical padding 10, or use 9 only together with `height: 1.25` on the label. The shared widget also fixes Sign in and the future Forgot-password step 1.

#### Phone entry - phone mode (sign-up step 1) `AUTH-10`
- **[MINOR · interaction] Phone input grabs focus on entry** `AUTH-10-F2`
  - Prototype: auth-screens.jsx:203 the phone TextInput has no autoFocus; only the email input has it (:207).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart:106-110 `EgyptPhoneField(controller: _phoneCtrl, autoFocus: true, ...)`
  - Fix: Remove `autoFocus: true` from the phone field and keep it on the email field.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · layout] Code boxes are fixed 44x54 and centred instead of spanning the full width** `AUTH-12-F1`
  - Prototype: auth-screens.jsx:258 `justifyContent: 'space-between', gap: 8`; :269 `width: '100%', minWidth: 0, aspectRatio: '1 / 1.15'`. On a 393px screen each box is about 50.8x58.4.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:72-74 `PinTheme(width: 44, height: 54, ...)` inside `Center` (:127-139).
  - Fix: Size the cells from the constraints: `LayoutBuilder(builder: (c, bc) { final w = (bc.maxWidth - 5 * 8) / 6; final t = _pinTheme(AppColors.divider).copyWith(width: w, height: w * 1.15); return Pinput(defaultPinTheme: t, ...); })`

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · responsive] Fixed cell widths overflow on 320dp screens** `AUTH-12-F2`
  - Prototype: The flex cells shrink (`minWidth: 0`, auth-screens.jsx:269).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:72-74, 132: 6x44 + 5x8 = 304dp of fixed width, but only 272dp is available at 320dp because of the 24px gutters (step_header.dart:96).
  - Fix: The LayoutBuilder sizing in AUTH-12-F1 fixes this too.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · content] Destination is not bold plum900 and loses the user's spacing** `AUTH-12-F3`
  - Prototype: auth-screens.jsx:255 `We sent a 6-digit code to <strong style={{ color: aiwa.plum900 }}>{identifier}</strong>.` where identifier is `+20 ${value}` = '+20 100 555 8821' (prototype.jsx:629).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:123 `subtitle: 'We sent a 6-digit code to ${widget.identifier}.'` as plain text. The identifier is built as '+20' + digits only (phone_entry_page.dart:47), giving '+201005558821'.
  - Fix: Give StepHeader a `Widget? subtitleWidget` and pass `Text.rich(TextSpan(children: [const TextSpan(text: 'We sent a 6-digit code to '), TextSpan(text: display, style: TextStyle(color: AppColors.plum900, fontWeight: FontWeight.w700)), const TextSpan(text: '.')]))`, where display = '+20 ' + the value as typed.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · content] Tip box copy differs** `AUTH-12-F4`
  - Prototype: auth-screens.jsx:293 'Tip — for this prototype, any 6 digits will work. In production, AIWA calls POST /auth/verify-otp.'
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:194 "Didn't get it? Check the number, then tap Resend once the timer ends."
  - Fix: The prototype text is a demo note, so keeping the production copy is reasonable; get design sign-off. The box styling (otp_page.dart:176-203) already matches.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · interaction] Code auto-submits on the 6th digit** `AUTH-12-F5`
  - Prototype: Verification happens only when Verify is tapped (auth-screens.jsx:297).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:137 `onCompleted: (_) => _verify()`
  - Fix: Remove onCompleted, or confirm auto-submit with design.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · states] Focused empty cell gets a plum700 border** `AUTH-12-F6`
  - Prototype: auth-screens.jsx:272 `border: 1.5px solid ${d ? aiwa.plum700 : aiwa.divider}` with `outline: 'none'`: only filled cells turn plum.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:134 `focusedPinTheme: _pinTheme(AppColors.plum700)`
  - Fix: Use `focusedPinTheme: _pinTheme(AppColors.divider)` and keep `submittedPinTheme` as plum700.

#### OTP - enter the 6-digit code (countdown running) `AUTH-12`
- **[MINOR · interaction] OTP field grabs focus and opens the keyboard on arrival** `AUTH-12-V1`
  - Prototype: auth-screens.jsx:260-276: the six inputs have no autoFocus. Focus moves only while typing (:243) or on Resend (:249).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:131 `autofocus: true`. The keyboard opens immediately, and with focusedPinTheme plum700 (:134) the first empty cell is drawn plum700.
  - Fix: Remove `autofocus: true` from the Pinput, or confirm auto-focus with design (same decision as AUTH-10-F2).

#### OTP - resend available (timer at 0) `AUTH-13`
- **[MINOR · interaction] Focus is not returned to the first box after resend** `AUTH-13-F2`
  - Prototype: auth-screens.jsx:249 `inputs.current[0]?.focus()`
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:161-162 only calls `_controller.clear(); _startTimer();`
  - Fix: Give Pinput a `FocusNode _focus` and call `_focus.requestFocus()` after clear().

#### Account setup - name, optional email, password `AUTH-14`
- **[MINOR · components] Password eye toggle is 18px instead of 16px** `AUTH-14-F1`
  - Prototype: auth-screens.jsx:353-355 button with `padding: 4` and `<Icon name={showPass ? 'eye-off' : 'eye'} size={16} />` in ink3.
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart:163-172 `IconButton(icon: Icon(..., size: 18, color: AppColors.ink3))`
  - Fix: Apply the AUTH-06-F4 snippet here too (size 16, padding 4, empty constraints).

#### Account setup - inline validation errors `AUTH-15`
- **[MINOR · layout] Hint is hidden while an error shows** `AUTH-15-F1`
  - Prototype: The Field gets no `error` prop here, so its hint still renders (auth-screens.jsx:27), below the child error div (:335). Result: input, then error line, then hint.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:131-152 `if (hasError) ... else if (hint != null ...)` hides the hint while the error is visible.
  - Fix: Add `bool keepHintOnError` to AiwaTextField that renders the error then the hint, and set it from account_setup_page.dart.

#### Account setup - inline validation errors `AUTH-15`
- **[MINOR · components] Error line gets an icon the prototype doesn't use here** `AUTH-15-F2`
  - Prototype: auth-screens.jsx:335/341/373 plain `<div style={{ fontSize: 11.5, color: aiwa.danger700, marginTop: 5 }}>` with no icon. The Field variant with alert-circle (:28-30) is not used on this screen.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:133-140 `Icon(Icons.error_outline_rounded, size: 12, color: AppColors.danger700)`
  - Fix: Add `showErrorIcon` (default true) to AiwaTextField and pass false from AccountSetupPage.

#### Account setup - inline validation errors `AUTH-15`
- **[MINOR · tokens] Input border turns danger500 on error** `AUTH-15-F3`
  - Prototype: auth-screens.jsx:39 TextInput border is always `1.5px solid ${aiwa.divider}` (male #D8CFC2 / female #EFDCD6).
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:115-121 enabled and focused borders use `AppColors.danger500` when hasError (male #2E2A26 / female #6B3A3A).
  - Fix: Keep the divider border in the error state for this screen, or globally if the DS audit agrees.

#### Password strength meter `AUTH-16`
- **[MINOR · layout] Meter renders below the hint instead of directly under the input** `AUTH-16-F1`
  - Prototype: The meter is inside the Password Field right after the TextInput (auth-screens.jsx:358), followed by passErr (:373) and then the hint (Field, :27).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart:156-208 renders the meter after the whole AiwaTextField, below the 'At least 6 characters.' hint or error.
  - Fix: Add a `Widget? belowInput` slot to AiwaTextField, rendered between the TextFormField and the hint/error, and pass the meter Row into it.

#### Make it yours - avatar + gender (sign-up step 4) `AUTH-17`
- **[MINOR · layout] Vertical spacing around the avatar and gender field differs** `AUTH-17-F4`
  - Prototype: auth-screens.jsx:418 avatar block `marginTop: 22, marginBottom: 18`; Field label -> grid 6 (:22); grid -> hint 5 (:27).
  - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:147 `SizedBox(height: 24)`, :149 `SizedBox(height: 10)`, :167 `SizedBox(height: 6)`.
  - Fix: Use 18, 6 and 5.

#### Field + TextInput (form atoms) `AUTH-25`
- **[MINOR · states] Inputs show a plum700 focus border the prototype doesn't have** `AUTH-25-F1`
  - Prototype: auth-screens.jsx:38-40 border fixed at `1.5px solid ${aiwa.divider}` with `outline: 0` on the input (:50): no focus colour.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:119-121 `focusedBorder: AppTheme.inputBorder(hasError ? AppColors.danger500 : AppColors.plum700)`. The same rule is in EgyptPhoneField (step_header.dart:233) and the global inputDecorationTheme (app_theme.dart:179).
  - Fix: For a strict match, set focusedBorder to AppColors.divider. Recommended instead: confirm with design, because a visible focus ring helps accessibility (the legacy LoginScreen at prototype.jsx:110 did use a plum700 border).

#### Field + TextInput (form atoms) `AUTH-25`
- **[MINOR · layout] Input text starts 4px further in than the prototype (Material 3 input gaps)** `AUTH-25-V1`
  - Prototype: auth-screens.jsx:37-42 input row `padding: '13px 14px'`, `gap: 10`. Text starts 14px from the border without an icon, or 14+17+10 = 41px after a leading icon.
  - Flutter now: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart:101-127 uses prefix Padding(left 14, right 10) and contentPadding h14, under `ThemeData.light(useMaterial3: true)` (app_theme.dart:100). The Flutter 3.49 InputDecorator adds prefixToInputGap = 4 after a prefixIcon and inputGap = OutlineInputBorder.gapPadding (default 4) when there is none (Flutter SDK material/input_decorator.dart:737, 2632-2637). Text therefore starts at 45px on icon fields and 18px on EgyptPhoneField (step_header.dart:226-238).
  - Fix: In AppTheme.inputBorder, return `OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: 1.5), gapPadding: 0)` (no floating labels are used), so icon-less fields start at 14px. Change the AiwaTextField prefix padding to `EdgeInsets.only(left: 14, right: 6)` so icon fields start at 41px.

#### Cross-cutting `-`
- **[MINOR · interaction] Tappable cards and pills have no pressed scale** `AUTH-CF-01`
  - Prototype: prototype.html:41-42 `button { transition: transform 120ms cubic-bezier(.32,.72,0,1), background 200ms; } button:active:not(:disabled) { transform: scale(.96); }`. This applies to every <button>, including role cards, auth-choice cards, language pills, the mode toggle and gender cards.
  - Flutter now: Only AiwaButton scales, and it uses 0.97 (Android/aiwa_app/lib/shared/widgets/aiwa_button.dart:114-116). Role cards (role_choice_page.dart:110), auth-choice cards (auth_choice_page.dart:180), language pills (splash_page.dart:224), IdentifierModeToggle (step_header.dart:146) and gender cards (avatar_gender_page.dart:195) are bare GestureDetectors with no pressed state.
  - Fix: Add a small `PressScale` widget in lib/shared/widgets (AnimatedScale to 0.96, 120ms, AppTheme.easeSoft, driven by onTapDown/onTapUp/onTapCancel), wrap these GestureDetectors in it, and set AiwaButton's pressed scale to 0.96.

#### Cross-cutting `-`
- **[MINOR · interaction] Route transitions use platform defaults instead of the prototype slide/fade** `AUTH-CF-02`
  - Prototype: prototype.jsx:726-731: forward navigation uses `aiwa-slide-in` (translateX 8% -> 0) and back/reset uses `aiwa-fade-in` (scale .98 -> 1), both 320ms cubic-bezier(.32,.72,0,1) (prototype.html:16-23).
  - Flutter now: Android/aiwa_app/lib/core/router/app_router.dart:68-144: the auth GoRoutes use plain `builder:`, so they get the default MaterialPage transitions.
  - Fix: Use `pageBuilder: (c, s) => CustomTransitionPage(child: ..., transitionDuration: AppTheme.dur3, transitionsBuilder: (c, a, _, child) => SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).chain(CurveTween(curve: AppTheme.easeSoft)).animate(a), child: child))` for the auth routes.
