# Sign-in / sign-up fixes + forgot password

Generated from the AIWA prototype-fidelity audit. Paths: prototype = `C:/Users/alyar/Desktop/AIWA Design System (2)/design_handoff_aiwa_app/`, Flutter = `Android/aiwa_app/`.

## Targeted findings

- **[MINOR · interaction] Tappable cards and pills have no pressed scale** `AUTH-CF-01`
  - Prototype: prototype.html:41-42 `button { transition: transform 120ms cubic-bezier(.32,.72,0,1), background 200ms; } button:active:not(:disabled) { transform: scale(.96); }`. This applies to every <button>, including role cards, auth-choice cards, language pills, the mode toggle and gender cards.
  - Flutter now: Only AiwaButton scales, and it uses 0.97 (Android/aiwa_app/lib/shared/widgets/aiwa_button.dart:114-116). Role cards (role_choice_page.dart:110), auth-choice cards (auth_choice_page.dart:180), language pills (splash_page.dart:224), IdentifierModeToggle (step_header.dart:146) and gender cards (avatar_gender_page.dart:195) are bare GestureDetectors with no pressed state.
  - Fix: Add a small `PressScale` widget in lib/shared/widgets (AnimatedScale to 0.96, 120ms, AppTheme.easeSoft, driven by onTapDown/onTapUp/onTapCancel), wrap these GestureDetectors in it, and set AiwaButton's pressed scale to 0.96.

- **[MINOR · interaction] Route transitions use platform defaults instead of the prototype slide/fade** `AUTH-CF-02`
  - Prototype: prototype.jsx:726-731: forward navigation uses `aiwa-slide-in` (translateX 8% -> 0) and back/reset uses `aiwa-fade-in` (scale .98 -> 1), both 320ms cubic-bezier(.32,.72,0,1) (prototype.html:16-23).
  - Flutter now: Android/aiwa_app/lib/core/router/app_router.dart:68-144: the auth GoRoutes use plain `builder:`, so they get the default MaterialPage transitions.
  - Fix: Use `pageBuilder: (c, s) => CustomTransitionPage(child: ..., transitionDuration: AppTheme.dur3, transitionsBuilder: (c, a, _, child) => SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).chain(CurveTween(curve: AppTheme.easeSoft)).animate(a), child: child))` for the auth routes.

- **[CRITICAL · interaction] Pages under the current route still react to the shared AuthBloc** `AUTH-CF-03`
  - Prototype: prototype.jsx:547-560: one navigation stack, and each screen's callback fires once for its own action.
  - Flutter now: SplashPage (splash_page.dart:68-79), SignInPage (sign_in_page.dart:63-74), PhoneEntryPage (phone_entry_page.dart:63-79), OtpPage (otp_page.dart:89-107) and AvatarGenderPage (avatar_gender_page.dart:68-79) all listen to the single global AuthBloc (app.dart:18-21) and stay mounted under pushed routes. One state change therefore triggers several pages: Resend pushes a duplicate OTP page, errors show 2-3 stacked SnackBars, and on registration both Splash (go home/providerDashboard) and AvatarGender (go home/providerPending) call context.go.
  - Fix: Add `listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? false` to each of these BlocListeners, or move the sign-up steps to a page-scoped cubit.

- **[MAJOR · components] No toast component; auth feedback uses default bottom SnackBars** `AUTH-CF-04`
  - Prototype: prototype.jsx:20-39 Toast: top-anchored, rgba(42,19,32,.96) background, 26px success check badge, 13px/500 text, slide-down 320ms, auto-dismiss 2.8s. It carries every auth confirmation ('Welcome back, Layla.', 'Password reset. Please sign in.').
  - Flutter now: lib/shared/widgets has no toast. Auth pages call ScaffoldMessenger SnackBars (e.g. Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart:75-77), styled by app_theme.dart:185-193: plum900 at 96%, floating at the bottom, 14px text, no icon.
  - Fix: Build a shared `showAiwaToast` (see the AUTH-09 build notes) and use it for success messages. Keep SnackBars for errors or restyle them to match.


## Entries

### Splash - language picker + Browse as guest — `AUTH-01` (screen, deviates)
- How the user reaches it: App launch (CustomerApp initial stack [{name:'splash'}], prototype.jsx:506); also reset('splash') after sign-out / delete account / session expired
- Prototype source: ui_kits/aiwa-app/prototype.jsx:44-86 (SplashScreen); route case prototype.jsx:612-614
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/core/router/app_router.dart
- Key elements: 160deg plum700->plum900 gradient (male #2E2A26 / female #6B3A3A) with two hardcoded radial glows rgba(231,186,182,.5) and rgba(216,185,138,.3); Wordmark height 56, bone text, rose500 dot; 'Beauty & grooming, near you.' DM Serif Display 34, lh 1.05, maxWidth 280; 'Trusted barbers, hairdressers, nail artists, and spas — one tap away.' 14px rose300; Eyebrow 'Choose your language' rose300; English pill: bone bg, plum900 text 15/600, arrow-right 18; العربية pill: Markazi Text 20/500, direction rtl, arrow-left, rgba(250,245,238,.12) bg, .25 border; 'Browse as guest →' 13/600 rose300 link -> Home as guest (preferredLanguage EN)
- Findings:
  - **[MAJOR · tokens] Splash glows use themed stone tokens at about half the prototype's size instead of fixed rose/gold washes** `AUTH-01-F1`
    - Prototype: prototype.jsx:51 inset:0 layer `radial-gradient(circle at 30% 25%, rgba(231,186,182,.5), transparent 55%), radial-gradient(circle at 75% 80%, rgba(216,185,138,.3), transparent 60%)`. These are literal #E7BAB6 @50% and #D8B98A @30% in both themes. The circles use the default farthest-corner size, so on the 393x852 frame glow 1 fades out about 383px from (118,213) and glow 2 about 446px from (295,682).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart:87-104 has `AiwaGlow(size: 360, color: AppColors.rose300, opacity: 0.35)` at left -80/top -40 and `AiwaGlow(size: 300, color: AppColors.gold300, opacity: 0.22)` at right -90/bottom 60. AiwaGlow (Android/aiwa_app/lib/shared/widgets/screen_chrome.dart:426-452) fades to 0 at its own radius, so glow 1 ends 180px from (100,140) and glow 2 ends 150px from (W-60,H-210). Both colours are gender-aware and resolve to male #B5A898 / female #E6BAB0.
    - Fix: In splash_page.dart (import 'dart:math' as math), replace both AiwaGlow widgets with full-bleed gradients sized like CSS farthest-corner:
  ```dart
  Positioned.fill(child: LayoutBuilder(builder: (_, bc) {
    final w = bc.maxWidth, h = bc.maxHeight, s = math.min(w, h);
    double far(double x, double y) => math.sqrt(math.pow(math.max(x, w - x), 2) + math.pow(math.max(y, h - y), 2));
    Widget glow(Alignment c, double cx, double cy, Color col, double stop) => SizedBox.expand(child: DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: c, radius: far(cx, cy) / s, colors: [col, col.withOpacity(0)], stops: [0, stop]))));
    return Stack(children: [
      glow(const Alignment(-0.4, -0.5), w * .3, h * .25, const Color(0x80E7BAB6), .55),
      glow(const Alignment(0.5, 0.6), w * .75, h * .8, const Color(0x4DD8B98A), .6),
    ]);
  }))
  ```
  The 160deg vs topLeft->bottomRight gradient angle makes no visible difference because plum700 == plum900 in both palettes.
  - **[MAJOR · interaction] Picking Arabic is discarded and never reaches the signup payload** `AUTH-01-F2`
    - Prototype: prototype.jsx:613 `onPick={(lang) => { setSignup(p => ({ ...p, preferredLanguage: lang === 'ar' ? 'AR' : 'EN' })); push('role-choice'); }}`. preferredLanguage is part of the User payload (auth-screens.jsx:3).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart:55 `await prefs.setString('aiwa_language', code);`. Nothing in lib/ ever reads that key. AuthRegisterEvent (auth_event.dart:19-36) and the datasource register body (auth_remote_datasource.dart:60-79) have no preferredLanguage field, so the backend stores its default `Language.EN` (AuthRequest.java) even for Arabic users.
    - Fix: Add `final String preferredLanguage;` to AuthRegisterEvent, RegisterUseCase and AuthRemoteDataSource.register, and send `body['preferredLanguage'] = lang == 'ar' ? 'AR' : 'EN'`. Read SharedPreferences('aiwa_language') in AvatarGenderPage._continue. For users who sign in instead, PATCH ApiConstants.meLanguage after login.
  - **[CRITICAL · states] Language choices never appear if the stored-session check fails; splash fades in over 900ms instead of sliding in** `AUTH-01-F3`
    - Prototype: prototype.jsx:61-83: the choices render on first paint. The only entrance motion is the stack wrapper's `aiwa-slide-in 320ms cubic-bezier(.32,.72,0,1)` (initial direction 'forward' at prototype.jsx:507, applied at :726-731; translateX 8%->0 per prototype.html:16-19).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/splash_page.dart:35-44: `_showChoices` starts false unless AuthBloc is already AuthUnauthenticated/AuthError. Until then :149-151 renders `SizedBox(height: 160)`, and :26-29 adds a 900ms FadeTransition. With a stored token, AuthBloc._onCheckSession (auth_bloc.dart:40-52) awaits GET /auth/me. If that fails at the HTTP or network level (offline, or the refresh token has expired), _ErrorInterceptor throws NetworkException/UnauthorizedException inside Dio (api_client.dart:140-161). dio 5.9.2 re-wraps it as DioException(type: unknown) (dio_mixin.dart:516-523), which AuthRepositoryImpl.getCurrentUser (auth_repository_impl.dart:96-107) does not catch. The handler throws, bloc 8.1.4 rethrows, and the state stays AuthInitial. The splash then shows no language pills and no 'Browse as guest' link, permanently.
    - Fix: (1) In ApiClient, unwrap interceptor exceptions (see the corrected AUTH-08-F1 fix). (2) Wrap AuthBloc._onCheckSession in try/catch and emit AuthUnauthenticated() on any error. (3) In splash_page.dart show the choices unless a stored session is being checked, e.g. `context.read<SecureStorage>()`/sl<SecureStorage>().hasValidSession().then((has) { if (!has && mounted) setState(() => _showChoices = true); });`. Replace the 900ms FadeTransition with a 320ms `SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).chain(CurveTween(curve: AppTheme.easeSoft)).animate(_controller))`.

### Wordmark (AIWA serif logotype + dot) — `AUTH-02` (component, deviates)
- How the user reaches it: Splash hero (prototype.jsx:53, height 56). Also used in the admin header (admin-screens.jsx:66), which is out of scope.
- Prototype source: ui_kits/aiwa-app/prototype.jsx:5-13 (Wordmark)
- Flutter files: Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: SVG viewBox 320x100, width = height*3.2; text 'AIWA' DM Serif Display fontSize 84, letterSpacing -2, baseline y=74; dot: circle cx=307 cy=68 r=6, colour = dot prop (rose500)

### Role choice - How will you be using AIWA? — `AUTH-04` (screen, deviates)
- How the user reaches it: Splash -> English / العربية -> Role choice
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:83-158 (RoleChoiceScreen); route prototype.jsx:615
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/role_choice_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart, Android/aiwa_app/lib/shared/widgets/aiwa_button.dart
- Key elements: back IconBtn; Eyebrow 'Welcome to AIWA'; h1 30 'How will you be using AIWA?'; 'You can change this later from your profile.'; Customer card: sparkles, 'I'm here to book', sub, 3 perks; Provider card: briefcase, 'I'm offering services', sub, 3 perks; active card: plum700 fill, bone title, rose300 sub/perks, check-circle; Continue lg (opacity .45 until a role is picked)

### Auth choice - Create account vs I already have an account (customer & provider copy) — `AUTH-05` (screen, deviates)
- How the user reaches it: Splash -> language -> Role choice -> Continue -> Auth choice. 'I'm here to book' shows the customer copy; 'I'm offering services' shows the provider copy.
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:762-848 (AuthChoiceScreen); route prototype.jsx:616-618
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/auth_choice_page.dart, Android/aiwa_app/lib/shared/widgets/aiwa_icon_button.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart
- Key elements: top-50% hero gradient plus glows rgba(231,186,182,.45) / rgba(216,185,138,.25); glass back IconBtn; Eyebrow 'Customer · Welcome' / 'Provider · Welcome' in rose300; h1 32 bone 'Beauty & grooming, near you.' / 'Run your beauty studio with AIWA.'; sub in rose300; 80px spacer; card 'Create an account' / 'Set up a new studio' with plum700 tile, sparkles/briefcase, 'Takes about a minute.' / 'ID verification required.', shadow; card 'I already have an account' with plum100 tile, log-in icon, 'Sign in with phone or email.'; footer: shield-check + 'Protected by AIWA's safety policy'
- Findings:
  - **[MAJOR · tokens] Auth-choice hero glows are themed and undersized; the primary card shadow is themed instead of the literal** `AUTH-05-F1`
    - Prototype: auth-screens.jsx:781-786: hero `inset: '0 0 50% 0'` with `radial-gradient(circle at 30% 25%, rgba(231,186,182,.45), transparent 60%), radial-gradient(circle at 75% 80%, rgba(216,185,138,.25), transparent 60%)`. On the 393x426 hero, glow 1 fades out about 253px from (118,106) and glow 2 about 271px from (295,341). :812 `boxShadow: '0 12px 32px rgba(74,31,56,.18)'` (literal #4A1F38).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/auth_choice_page.dart:48-61: `AiwaGlow(size: 320, color: AppColors.rose300)` (default opacity 0.35, radius 160, centre (100,120)) and `AiwaGlow(size: 260, color: AppColors.gold300, opacity: 0.25)` (radius 130, centre ≈(W-70, H/2-50)). Both resolve to male #B5A898 / female #E6BAB0. :188 `AppTheme.shadow3` is plum700 @18%, blur 32, y 12 (male #2E2A26 / female #6B3A3A).
    - Fix: Inside the hero Container (auth_choice_page.dart:43-63), use the farthest-corner glow helper from AUTH-01-F1 with `Color(0x73E7BAB6)` at Alignment(-0.4,-0.5) and `Color(0x40D8B98A)` at Alignment(0.5,0.6), both with stops [0, .6], computed on the hero's own box. For the sign-up card use `boxShadow: const [BoxShadow(color: Color(0x2E4A1F38), blurRadius: 32, offset: Offset(0, 12))]`.

### Sign in - phone mode — `AUTH-06` (screen, deviates)
- How the user reaches it: Splash -> language -> Role choice -> Continue -> Auth choice -> 'I already have an account'
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:854-981 (SignInScreen); route prototype.jsx:619-626
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart, Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart, Android/aiwa_app/lib/features/auth/presentation/bloc/auth_bloc.dart
- Key elements: back IconBtn; Eyebrow 'Welcome back' / 'Provider sign in'; h1 30 'Sign in to AIWA'; 'Use the number and password you signed up with.'; Phone/Email pill toggle; Field 'Phone number': 🇪🇬 +20 box + input (placeholder 100 555 8821); Field 'Password': lock icon, eye toggle; 'Remember me' checkbox (on by default); 'Forgot password?' link; Sign in lg (disabled until ≥9 digits and password ≥6); 'New to AIWA? Create an account'
- Findings:
  - **[CRITICAL · interaction] 'Forgot password?' is a dead end** `AUTH-06-F1`
    - Prototype: auth-screens.jsx:960-962 button -> onForgot -> prototype.jsx:625 `onForgot={() => { push('forgot-password'); }}`, which opens the 3-step ForgotPasswordScreen.
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:223-230 `onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset is coming soon — contact support for now.')))`
    - Fix: Add `static const forgotPassword = '/forgot-password'` plus a GoRoute to ForgotPasswordPage (AUTH-20..22), and change onTap to `context.push(AppRoutes.forgotPassword)`. The backend already exposes POST /auth/reset-password (AuthController.java:240-245).
  - **[CRITICAL · interaction] Provider sign-in skips the pending-verification gate** `AUTH-06-F2`
    - Prototype: prototype.jsx:622 `if (signup.role === 'PROVIDER') { reset('provider-pending'); } else { reset('home'); setTab('home'); }`
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:66-70 `context.go(state.user.isProvider ? AppRoutes.providerDashboard : AppRoutes.home)`. This ignores `user.providerProfile?.isApproved` (user_entity.dart:66), so an unverified provider lands on the dashboard.
    - Fix: ```dart
  final u = state.user;
  context.go(!u.isProvider
      ? AppRoutes.home
      : (u.providerProfile?.isApproved ?? false)
          ? AppRoutes.providerDashboard
          : AppRoutes.providerPending);
  ```
  Apply the same rule in splash_page.dart:71-75.

### Sign in - email mode — `AUTH-07` (tab, deviates)
- How the user reaches it: Auth choice -> I already have an account -> tap 'Email'
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:894-923
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart
- Key elements: Email segment active (paper bg, plum900, shadow 0 1px 3px); sub 'Use the email and password you signed up with.'; Field 'Email' with mail icon, placeholder 'you@example.com', autoFocus; switching tabs clears the error

### Sign in - wrong credentials error — `AUTH-08` (state, deviates)
- How the user reaches it: Sign in -> submit a password that doesn't match (the prototype uses the literal password 'wrong')
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:867-876, 941-946
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart, Android/aiwa_app/lib/shared/widgets/screen_chrome.dart, Android/aiwa_app/lib/core/errors/failures.dart, Android/aiwa_app/lib/features/auth/data/repositories/auth_repository_impl.dart
- Key elements: danger100 box, radius 10, padding 10x12, gap 8; alert-circle 14 in danger700; 12.5px danger700 text "That phone/email and password don't match."; cleared on any input change or tab switch
- Findings:
  - **[CRITICAL · states] Wrong password never shows an error; Sign in stays stuck in its loading pulse** `AUTH-08-F1`
    - Prototype: auth-screens.jsx:870-872 `if (password === 'wrong') { setError("That phone/email and password don't match."); return; }`, rendered as the danger100 box at :941-946. The Sign in button stays usable.
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/sign_in_page.dart:71-72 would show `state.message`, but no AuthError is emitted for bad credentials. The backend answers 401 (GlobalExceptionHandler.java:66-69). Android/aiwa_app/lib/core/network/api_client.dart:152-153 throws UnauthorizedException inside the Dio error interceptor, and dio 5.9.2 re-wraps any non-DioException thrown there as DioException(type: unknown) (dio_mixin.dart:516-523). auth_repository_impl.dart:28-34 only catches ServerException/NetworkException/UnauthorizedException, so AuthBloc._onLogin (auth_bloc.dart:54-70) throws, bloc 8.1.4 rethrows, and the global state stays AuthLoading. The Sign in button keeps pulsing and stays disabled (sign_in_page.dart:84, aiwa_button.dart:55), as does every other auth CTA bound to the same bloc, until the app restarts. Even if the exception were unwrapped, the text would be failures.dart:16 'Unauthorized. Please sign in again.'
    - Fix: 1) In ApiClient (api_client.dart:29-84), route every call through an unwrapping helper:
  ```dart
  Future<Response<T>> _run<T>(Future<Response<T>> Function() f) async {
    try { return await f(); } on DioException catch (e) {
      final inner = e.error;
      if (inner is ServerException || inner is UnauthorizedException || inner is NetworkException) throw inner!;
      rethrow;
    }
  }
  ```
  2) In AuthRepositoryImpl.login, map `on UnauthorizedException` to `const Left(ServerFailure("That phone/email and password don't match.", statusCode: 401))`. 3) Add a catch-all in the AuthBloc handlers that emits AuthError, so the bloc can never stay in AuthLoading.

### Toast - 'Welcome back, Layla.' — `AUTH-09` (toast, missing)
- How the user reaches it: Sign in -> valid credentials -> Home (the toast overlays the new screen)
- Prototype source: ui_kits/aiwa-app/prototype.jsx:621 (setToast) + Toast component prototype.jsx:20-39
- Flutter files: none yet
- Key elements: anchored at the top (top 56, 16px sides); rgba(42,19,32,.96) background, radius 14, padding 12x16, blur 8; 26px success500 circle with a white 15px check; 13px/500 bone text; shadow 0 12px 32px rgba(74,31,56,.3); aiwa-toast slide-down 320ms, auto-dismiss after 2800ms
- To build: No toast exists in lib/shared/widgets. Build `showAiwaToast(BuildContext, String)` there: an OverlayEntry on rootNavigatorKey.currentState!.overlay, positioned at MediaQuery.padding.top + 12 with 16px sides, a Container of Color(0xF52A1320), radius 14 and padding 12x16, a 26px AppColors.success500 circle with Icons.check_rounded 15 white, text 13/w500 bone, animated with SlideTransition + FadeTransition over 320ms AppTheme.easeSoft, removed after a 2800ms Timer. Call it in SignInPage's AuthAuthenticated branch (sign_in_page.dart:65) with `'Welcome back, ${state.user.fullName.split(' ').first}.'` before context.go. Use the root overlay because go() replaces the route.

### Phone entry - phone mode (sign-up step 1) — `AUTH-10` (screen, deviates)
- How the user reaches it: Auth choice -> Create an account (or Sign in -> 'Create an account')
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:164-221 (PhoneEntryScreen); route prototype.jsx:627
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart, Android/aiwa_app/lib/features/auth/presentation/bloc/auth_bloc.dart
- Key elements: StepHeader 'Step 1 of 4' (6 for provider) "What's your phone number?" / "We'll send a 6-digit code to confirm."; Phone/Email pill toggle (cream track, padding 4, gap 4); 🇪🇬 +20 box + phone TextInput (placeholder 100 555 8821); terms / safety policy line 11.5 ink3 with plum700 600 words; Send code lg (disabled until ≥9 digits)

### Phone entry - email mode — `AUTH-11` (tab, deviates)
- How the user reaches it: Phone entry -> tap 'Email'
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:169-175, 206-208, 215; prototype.jsx:627-630
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart
- Key elements: title "What's your email?"; mail TextInput, autoFocus, placeholder 'you@example.com'; Send code (valid on /.+@.+\..+/) -> OTP step 2 showing the email address
- Findings:
  - **[CRITICAL · interaction] Email sign-up skips the verification code step** `AUTH-11-F1`
    - Prototype: auth-screens.jsx:215 `onContinue({ mode, value })` -> prototype.jsx:627 `push('otp')`. The OTP screen then shows the email (prototype.jsx:629 `signup.identifier?.mode === 'email' ? signup.identifier.value : ...`).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart:52-57 `// Email flow — no OTP endpoint for email, go straight to account setup.` then `context.push(AppRoutes.accountSetup, ...)`. The progress bar jumps from Step 1 to Step 3 and email ownership is never verified.
    - Fix: Backend: let /auth/send-otp and /auth/verify-otp accept an email identifier. Flutter: rename the `phone` field of AuthSendOtpEvent/AuthVerifyOtpEvent to `identifier` and send email mode through `AuthSendOtpEvent(identifier: value)` -> OtpPage, the same as phone. Until the backend supports this, hide the Email tab on sign-up instead of silently skipping verification.
  - **[CRITICAL · interaction] Email sign-up can never finish: the email identifier is dropped from the register call** `AUTH-11-V1`
    - Prototype: prototype.jsx:627 stores `identifier: { mode: 'email', value }`, and :637 passes it to AccountSetupScreen. That screen hides its Email field for email sign-ups (auth-screens.jsx:314 `showEmailField = identifierMode === 'phone'`) because the identifier is already the account email. The flow then continues avatar-gender -> terms (prototype.jsx:638-645).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart:116-117 adds 'email' only when the hidden email field is non-empty. Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:54-55 sends `email: data['email'] as String?, phone: mode == 'phone' ? data['identifier'] as String? : null`, so both are null in email mode; provider_verification_page.dart:38-39 repeats this. The backend rejects the request with auth.error.email_or_phone_required (AuthServiceImpl.java:41-43, HTTP 400). Because of the Dio exception wrapping (AUTH-08-F1), no AuthError is emitted, and 'Continue' on Make it yours stays in its loading pulse.
    - Fix: In avatar_gender_page.dart `_continue` and provider_verification_page.dart:38, use `email: mode == 'email' ? data['identifier'] as String? : data['email'] as String?`. Also fix AUTH-11-F1 (verify the email by OTP) and the error unwrapping in AUTH-08-F1.

### OTP - enter the 6-digit code (countdown running) — `AUTH-12` (screen, deviates)
- How the user reaches it: Phone entry -> Send code -> OTP
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:226-303 (OTPScreen); route prototype.jsx:628-631
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart
- Key elements: StepHeader 'Step 2 of 4' 'Enter the code'; sub 'We sent a 6-digit code to <strong plum900>+20 100 555 8821</strong>.'; 6 full-width boxes (aspect 1:1.15, DM Serif 28 plum900, border plum700 once filled, radius 14); 'Resend code in 0:45' with the time in JetBrains Mono; cream tip box with info icon; Verify lg (disabled until 6 digits)

### OTP - resend available (timer at 0) — `AUTH-13` (state, deviates)
- How the user reaches it: OTP -> wait 45 s
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:249, 281-288
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart, Android/aiwa_app/lib/features/auth/presentation/pages/phone_entry_page.dart
- Key elements: 'Resend code' text button, plum700 600 13; tap: timer resets to 45, digits clear, first box focused
- Findings:
  - **[CRITICAL · interaction] Tapping Resend pushes a second OTP page** `AUTH-13-F1`
    - Prototype: auth-screens.jsx:249 `const resend = () => { setSeconds(45); setDigits(['','','','','','']); inputs.current[0]?.focus(); };`: the user stays on the same screen.
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/otp_page.dart:163-165 dispatches `AuthSendOtpEvent`, and the bloc emits AuthLoading then AuthOtpSent (auth_bloc.dart:98-103). PhoneEntryPage is still mounted under the OTP route, and its listener (phone_entry_page.dart:65-73) runs `context.push(AppRoutes.otp, ...)` again, stacking a duplicate OtpPage. Any AuthError on OTP is also shown twice (otp_page.dart:100-104 and phone_entry_page.dart:74-78).
    - Fix: Only let the visible route react:
  ```dart
  BlocListener<AuthBloc, AuthState>(
    listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? false,
    listener: ...,
  )
  ```
  Apply this in phone_entry_page.dart, otp_page.dart, sign_in_page.dart, avatar_gender_page.dart and splash_page.dart (CF-03).

### Account setup - name, optional email, password — `AUTH-14` (screen, deviates)
- How the user reaches it: OTP -> Verify -> Account setup
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:308-384 (AccountSetupScreen); route prototype.jsx:637-638
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart, Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart
- Key elements: StepHeader 'Step 3 of 4' 'Set up your account' / "A name and a password — that's it. We'll add the rest later."; Field 'Full name': user icon, 'e.g. Layla Hassan', hint 'Your real name — providers see it on bookings.'; Field 'Email' marked Optional (phone sign-ups only): mail icon, hint 'For receipts and account recovery.'; Field 'Password': lock, eye toggle, hint 'At least 6 characters.', strength meter; Continue (disabled until valid)

### Account setup - inline validation errors — `AUTH-15` (state, deviates)
- How the user reaches it: Account setup -> type a single name, an invalid email, or a password under 6 characters
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:316-319, 335, 341, 373
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart, Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart
- Key elements: 'Enter your first and last name'; "Doesn't look like a valid email"; 'At least 6 characters'; 11.5px danger700 line under the input, no icon, hint still shown, border unchanged; Continue stays disabled

### Password strength meter — `AUTH-16` (component, deviates)
- How the user reaches it: Account setup -> type in Password
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:321-323, 358-372
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/account_setup_page.dart
- Key elements: 4 bars (height 4, radius 2, gap 4); colour warn500 / info500 / success500 for length ≥6 / ≥8 / ≥12; label Weak / Okay / Good / Strong 11/600, right-aligned, min width 48; sits directly under the input (marginTop 8), above the error and hint

### Make it yours - avatar + gender (sign-up step 4) — `AUTH-17` (screen, deviates)
- How the user reaches it: Account setup -> Continue -> Make it yours
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:389-476 (AvatarGenderScreen); route prototype.jsx:639-646
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart, Android/aiwa_app/lib/core/theme/theme_controller.dart, Android/aiwa_app/lib/features/auth/presentation/bloc/auth_bloc.dart
- Key elements: StepHeader 'Step 4 of 4' 'Make it yours' / 'Add a photo, pick your palette. You can change both later.'; 128px tappable avatar: plum500->plum900 gradient, camera 36, 3px paper border, shadow 0 6px 18px; 38px plum700 '+' badge with 3px bone border; 'Upload a photo' link that opens the image picker; Field "I'm signing up as" + hint 'This sets the palette of your app.'; Woman / Man palette cards; CTA 'Continue without a photo' -> Terms
- Findings:
  - **[CRITICAL · interaction] Continue creates the account and jumps to Home, skipping Terms, Preferences and the permission screens** `AUTH-17-F1`
    - Prototype: prototype.jsx:640-645 `if (signup.role === 'PROVIDER') push('provider-business'); else push('terms');`. From there: terms (:652-655) -> preferences (:656) -> handleSavePrefs reset('perm-location') (:604) -> perm-notifications (:657) -> home (:658).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:49-59 dispatches AuthRegisterEvent for customers, and :70-73 runs `context.go(state.user.isProvider ? AppRoutes.providerPending : AppRoutes.home)`. Android/aiwa_app/lib/core/router/app_router.dart:29-55 has no /terms or /preferences route.
    - Fix: In avatar_gender_page.dart:70-73, send a newly registered customer to a new `/terms` GoRoute instead of AppRoutes.home (providers already push providerBusiness at :46-47). The Terms 'Agree' action calls POST /terms/accept?version=<v> with the new session (TermsController.java:43-56), then continues Preferences -> perm-location -> perm-notifications -> `context.go(AppRoutes.home)`. If no account may exist before terms are accepted, move AuthRegisterEvent into the Terms 'Agree' handler and call /terms/accept immediately after it succeeds. Add the /terms and /preferences routes in app_router.dart (screens covered by the ONB audit).
  - **[MAJOR · components] Photo upload is missing** `AUTH-17-F2`
    - Prototype: auth-screens.jsx:419-441: a tappable 128px circle opening `<input type="file" accept="image/*">`, a camera icon 36 when empty, a plus/pencil badge (38px, plum700, `border: 3px solid ${aiwa.bone}`), and an 'Upload a photo' / 'Replace photo' link (plum700 600 13).
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:102-143: a non-interactive circle showing the name's initial (AppTextStyles.display at 54) or Icons.person_outline_rounded 40, with the caption 'You can add a photo later from your profile.'
    - Fix: Wrap the circle in a GestureDetector that calls `ImagePicker().pickImage(source: ImageSource.gallery)` (image_picker is already in pubspec.yaml). Show `DecorationImage(image: FileImage(file), fit: BoxFit.cover)` once picked. Add `Positioned(right: 0, bottom: 0)` with a 38x38 plum700 circle, 3px bone border and Icons.add / Icons.edit 16. Add a TextButton 'Upload a photo' / 'Replace photo'. After registering, upload via POST /auth/me/avatar (AuthController.java:118).
  - **[MAJOR · content] Copy drops the photo step** `AUTH-17-F3`
    - Prototype: auth-screens.jsx:414 sub 'Add a photo, pick your palette. You can change both later.'; :472 CTA `{avatar ? 'Continue' : 'Continue without a photo'}`; :426 empty avatar shows a camera icon.
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:95 'Pick your palette. You can change it later.'; :83 `label: 'Continue'`; :141 'You can add a photo later from your profile.'
    - Fix: Restore the prototype subtitle and use `label: _avatar == null ? 'Continue without a photo' : 'Continue'`. Replace the caption with the Upload link and show Icons.camera_alt_outlined 36 in the empty circle.

### Make it yours - photo selected — `AUTH-18` (state, missing)
- How the user reaches it: Make it yours -> tap the avatar or 'Upload a photo' -> pick an image
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:402-408, 421, 432, 440, 472
- Flutter files: none yet
- Key elements: circle shows the photo as a cover image; badge icon switches to a pencil; link reads 'Replace photo'; CTA reads 'Continue'
- To build: Add `XFile? _avatar` to _AvatarGenderPageState and build the widgets from AUTH-17-F2. Pass the file through the registration data. After AuthRegisterEvent succeeds, upload it with multipart POST /auth/me/avatar: add `uploadAvatar(File)` to AuthRemoteDataSource and AuthRepository plus a use case, then refresh the user. Reuse AiwaButton for the label switch.

### Gender pick -> live palette swap — `AUTH-19` (state, deviates)
- How the user reaches it: Make it yours -> tap Woman / Man
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:389-400, 444-468; theme.jsx:12-66; prototype.jsx:535, 639-642
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart, Android/aiwa_app/lib/core/theme/theme_controller.dart, Android/aiwa_app/lib/core/theme/app_colors.dart, Android/aiwa_app/lib/app.dart
- Key elements: two cards with 3 swatches: Woman #6B3A3A/#C4837A/#FDF6F4, Man #2E2A26/#B5A898/#F5F2ED; selected card: plum100 background, 1.5px plum700 border; picking a card re-themes the whole app immediately; Woman is preselected (signup.gender 'FEMALE')
- Findings:
  - **[MAJOR · tokens] 'Man' card's Warm Stone swatch has the wrong colour** `AUTH-19-F1`
    - Prototype: auth-screens.jsx:448 `{ id: 'MALE', label: 'Man', swA: '#2E2A26', swB: '#B5A898', swC: '#F5F2ED' }`
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:193 `final colors = [swatches.plum700, swatches.rose500, swatches.bone];`. Male rose500 is #8A8074 (app_colors.dart:69). The female rose500 #C4837A happens to be correct.
    - Fix: Use `final colors = [swatches.plum700, swatches.plum300, swatches.bone];`. plum300 is male #B5A898 and female #C4837A, matching both prototype cards.
  - **[MAJOR · states] 'Man' is preselected where the prototype preselects 'Woman'** `AUTH-19-F2`
    - Prototype: prototype.jsx:535 `gender: 'FEMALE'` is passed as initialGender (:639). auth-screens.jsx:396-398 applies the female theme as soon as the screen mounts.
    - Flutter now: Android/aiwa_app/lib/features/auth/presentation/pages/avatar_gender_page.dart:32-34 `_gender` follows ThemeController.mode, which defaults to male (theme_controller.dart:16). So 'Man' is preselected and the palette doesn't change.
    - Fix: Use `late String _gender = 'FEMALE';` and in initState call `WidgetsBinding.instance.addPostFrameCallback((_) => ThemeController.applyGender(_gender, persist: false));`, persisting on Continue.

### Forgot password - step 1: where to send the code — `AUTH-20` (sub-screen, missing)
- How the user reaches it: Sign in -> Forgot password?
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:135-168 (ForgotPasswordScreen step 1); route prototype.jsx:625, 632
- Flutter files: none yet
- Key elements: back IconBtn (step 1 pops back to Sign in); Eyebrow 'Reset password'; h1 28 'Where should we send the code?'; Phone/Email pill toggle (no active shadow); single input with phone/mail icon 17 plum700, placeholder '100 555 8821' / 'you@example.com'; 'Send reset code' lg (opacity .45 until non-empty)
- To build: Create lib/features/auth/presentation/pages/forgot_password_page.dart with `int _step` (1..3), `_mode` and controllers, and register it as `AppRoutes.forgotPassword = '/forgot-password'` in app_router.dart. Reuse AuthStepScaffold, AiwaIconButton (back: step 1 -> context.pop(), otherwise setState(() => _step--)), EyebrowLabel, AppTextStyles.h1.copyWith(fontSize: 28, height: 1.08), IdentifierModeToggle (add a `shadow: false` option), AiwaTextField(icon: Icons.phone_outlined or Icons.mail_outline_rounded) and AiwaButton lg 'Send reset code'. For phone, call POST /auth/send-otp via a new ForgotPasswordCubit or AuthBloc event. The backend reset endpoint is phone-only (POST /auth/reset-password takes phone + code + new password, AuthController.java:240-245), so the email tab needs backend support first.

### Forgot password - step 2: enter the code — `AUTH-21` (sub-screen, missing)
- How the user reaches it: Forgot password step 1 -> Send reset code
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:169-182
- Flutter files: none yet
- Key elements: back -> step 1; Eyebrow 'Enter the code'; h1 'Check your messages.' / 'Check your inbox.'; input with key-round icon, JetBrains Mono 15, placeholder '6-digit code'; Verify enabled at ≥4 characters
- To build: Step 2 of ForgotPasswordPage: AiwaTextField(icon: Icons.key_outlined, placeholder: '6-digit code', keyboardType: TextInputType.number) with text style AppTextStyles.mono.copyWith(fontSize: 15), which needs a `textStyle` override on AiwaTextField. AiwaButton 'Verify' is enabled when code.length >= 4 (the prototype's threshold; backend codes have 6 digits). The code is sent with the new password in step 3; optionally call /auth/verify-otp here to fail fast.
- Findings:
  - **[MAJOR · interaction] Build-note correction: calling /auth/verify-otp at step 2 would break the reset at step 3** `AUTH-21-V1`
    - Prototype: flow-additions-v3.jsx:180: step 2 only checks `code.length >= 4` locally. Step 3 (:200) completes the reset with the new password.
    - Flutter now: Not visible: lib/ has no forgot-password page (a grep for forgot/resetPassword finds nothing). The AUTH-21 build notes suggest 'optionally call /auth/verify-otp here to fail fast'. However, AuthServiceImpl.java:207-209 resetPassword calls otpService.verifyOtp again, and OtpServiceImpl.java:45 deletes the code after the first successful verify, so step 3 would fail with otp.error.expired.
    - Fix: Keep step 2 client-side only: enable Verify at 6 digits to match backend codes, or at 4 per the prototype. Send phone + code + newPassword once, to POST /auth/reset-password in step 3. On a 400 otp.error.incorrect/expired, return to step 2 with an inline danger box.

### Forgot password - step 3: set a new password — `AUTH-22` (sub-screen, missing)
- How the user reaches it: Forgot password step 2 -> Verify
- Prototype source: ui_kits/aiwa-app/flow-additions-v3.jsx:183-202
- Flutter files: none yet
- Key elements: back -> step 2; Eyebrow 'Almost done'; h1 'Set a new password.'; two lock inputs: 'New password' / 'Confirm password'; 'Reset password' enabled when ≥6 characters and both match -> onDone
- To build: Two obscured AiwaTextFields (Icons.lock_outline_rounded, placeholders 'New password' / 'Confirm password', 10px apart). AiwaButton 'Reset password' is enabled when `pw.length >= 6 && pw == pw2`. On tap, dispatch a new AuthResetPasswordEvent(phone, code, newPassword) -> POST /auth/reset-password (add ApiConstants.resetPassword plus a datasource/repository/use case). On success pop back to SignInPage and show the AUTH-23 toast. On failure show an InlineBanner(tone: danger).

### Toast - 'Password reset. Please sign in.' — `AUTH-23` (toast, missing)
- How the user reaches it: Forgot password step 3 -> Reset password -> back on Sign in
- Prototype source: ui_kits/aiwa-app/prototype.jsx:632 (`onDone={() => { setToast('Password reset. Please sign in.'); pop(); }}`); Toast prototype.jsx:20-39
- Flutter files: none yet
- Key elements: same dark top toast with a success check badge; 'Password reset. Please sign in.'; auto-dismiss after 2.8 s
- To build: Use the shared toast from AUTH-09: `showAiwaToast(context, 'Password reset. Please sign in.')` followed by `context.pop()` back to SignInPage.

### StepHeader (back + progress + 'Step n of N' + title) — `AUTH-24` (component, implemented)
- How the user reaches it: Used on Phone entry, OTP, Account setup and Make it yours (plus the provider steps)
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:59-78
- Flutter files: Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart
- Key elements: 40px paper back IconBtn; progress row: 3px bars, gap 6, radius 2, plum700 done / divider pending, 18px below the back button; Eyebrow 'Step n of N' 16px below; h1 DM Serif 28 plum900, lh 1.08, -0.02em, margin 6/8; sub 13.5 ink2 lh 1.55

### Field + TextInput (form atoms) — `AUTH-25` (component, deviates)
- How the user reaches it: Every auth form (Sign in, Phone entry, Account setup)
- Prototype source: ui_kits/aiwa-app/auth-screens.jsx:19-57
- Flutter files: Android/aiwa_app/lib/shared/widgets/aiwa_text_field.dart, Android/aiwa_app/lib/core/theme/app_theme.dart, Android/aiwa_app/lib/features/auth/presentation/widgets/step_header.dart
- Key elements: Eyebrow label + 'Optional' tag (10/500 ink3), 6px gap; input row: padding 13x14, radius 14, paper, 1.5px divider border, leading icon 17 plum700 with 10px gap, 15px body text, optional suffix; hint 11.5 ink3, mt 5, lh 1.4; error 11.5 danger700 with alert-circle 12, gap 4; field bottom margin 14
