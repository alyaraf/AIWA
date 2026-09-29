import 'package:dartz/dartz.dart' show Either, Left;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../widgets/step_header.dart';
import 'splash_page.dart' show arabicStyle;
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// "Where should we look for providers?" — `PreferencesScreen` in
/// flow-screens.jsx. The last signup step: Save creates the account, then
/// accepts the terms and stores everything the earlier steps collected.
class PreferencesPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;
  const PreferencesPage({super.key, required this.registrationData});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  double _min = 1, _max = 5;
  String _lang = LocaleController.locale.value.languageCode;
  bool _busy = false;
  String? _error;

  /// Post-register steps already done, so a retry after a failure skips them
  /// (a second POST /provider/profile is rejected as already_exists).
  int _done = 0;

  Map<String, dynamic> get _d => widget.registrationData;
  bool get _isProvider => _d['role'] == 'PROVIDER';

  void _save() {
    setState(() => _error = null);
    // Already registered (a later step failed): just retry the rest.
    if (context.read<AuthBloc>().state is AuthAuthenticated) {
      _finish();
      return;
    }
    final mode = _d['mode'] as String? ?? 'phone';
    context.read<AuthBloc>().add(
      AuthRegisterEvent(
        fullName: _d['fullName'] as String,
        password: _d['password'] as String,
        // Email sign-ups carry the address as the identifier.
        email: mode == 'email'
            ? _d['identifier'] as String?
            : _d['email'] as String?,
        phone: mode == 'phone' ? _d['identifier'] as String? : null,
        role: _d['role'] as String? ?? 'CUSTOMER',
        gender: _d['gender'] as String?,
        preferredLanguage: _lang.toUpperCase(),
      ),
    );
  }

  Future<Either<Failure, void>> _acceptTerms(AuthRepository repo) async {
    // V13 seeds PROVIDER_TERMS, and /terms/accept checks the version against
    // the caller's role, so a provider can't fall back to the customer policy.
    final t = await repo.latestTerms(termsTypeFor(provider: _isProvider));
    return t.fold((f) async => Left(f), (p) => repo.acceptTerms(p.version));
  }

  /// After register: terms, radius, then the provider profile + documents.
  Future<void> _finish() async {
    final repo = sl<AuthRepository>();
    final steps = <Future<Either<Failure, void>> Function()>[
      () => _acceptTerms(repo),
      () => repo.updatePreferences(minKm: _min, maxKm: _max),
      if (_isProvider) ...[
        () => repo.createProviderProfile({
          'businessName': _d['businessName'],
          'bio': _d['bio'],
          'address': _d['address'],
          'latitude': _d['latitude'],
          'longitude': _d['longitude'],
          'primaryCategory': _d['primaryCategory'],
          'providerType': _d['businessType'] == 'shop' ? 'SHOP' : 'INDIVIDUAL',
        }, staff: (_d['staff'] as List?)?.cast<String>() ?? const []),
        () => repo.uploadVerificationDocuments(
          idFront: _d['idFront'] as String,
          idBack: _d['idBack'] as String,
          selfie: _d['selfie'] as String,
        ),
      ],
    ];
    setState(() => _busy = true);
    Failure? error;
    while (_done < steps.length && error == null) {
      error = (await steps[_done]()).fold((f) => f, (_) => null);
      if (error == null) _done++;
    }
    final avatar = _d['avatarPath'] as String?;
    // ponytail: photo is optional; a failed upload can be redone from Profile.
    if (error == null && avatar != null) await repo.uploadAvatar(avatar);
    if (!mounted) return;
    final message = error == null
        ? null
        : AppLocalizations.of(context).error(error.message);
    setState(() {
      _busy = false;
      _error = message;
    });
    if (message != null) return;
    ThemeController.applyGender(_d['gender'] as String?);
    LocaleController.set(_lang);
    // Pick up the saved radius / terms version on the signed-in user.
    context.read<AuthBloc>().add(AuthGetCurrentUserEvent());
    if (_isProvider) {
      showAiwaToast(
        context,
        AppLocalizations.of(context).authAccountCreatedReview,
      );
      context.go(AppRoutes.providerPending);
    } else {
      context.go(AppRoutes.permLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, _) => ModalRoute.of(context)?.isCurrent ?? false,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          _finish();
        } else if (state is AuthError) {
          setState(
            () => _error = AppLocalizations.of(context).error(state.message),
          );
        }
      },
      child: AuthStepScaffold(
        bottom: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => AiwaButton(
            label: AppLocalizations.of(context).prefsSave,
            size: AiwaButtonSize.lg,
            fullWidth: true,
            loading: state is AuthLoading || _busy,
            onPressed: _save,
          ),
        ),
        children: [
          AiwaIconButton(
            icon: LucideIcons.arrowLeftDir,
            onTap: () => context.pop(),
          ),
          const SizedBox(height: 22),
          EyebrowLabel(AppLocalizations.of(context).prefsLastStep),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).prefsTitle,
            style: AppTextStyles.h1.copyWith(
              fontSize: 30,
              height: 1.05,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).prefsSubtitle,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 14,
              color: AppColors.ink2,
              height: 1.55,
            ),
          ),
          // ponytail: prototype's "Your area" field dropped — nothing stores
          // or reads it (Home searches from GPS / the default address). Add it
          // back with a backend field (BE-19) if search must start elsewhere.
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: EyebrowLabel(
                  AppLocalizations.of(context).prefsSearchRadius,
                ),
              ),
              Text(
                AppLocalizations.of(
                  context,
                ).prefsRadiusRange(_min.round(), _max.round()),
                style: AppTextStyles.h4,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _min,
                  min: 1,
                  max: 25,
                  divisions: 24,
                  onChanged: (v) => setState(() {
                    _min = v;
                    if (v > _max) _max = v;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: _max,
                  min: 1,
                  max: 25,
                  divisions: 24,
                  onChanged: (v) => setState(() {
                    _max = v;
                    if (v < _min) _min = v;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).prefsMinKm(_min.round()),
                style: AppTextStyles.micro,
              ),
              Text(
                AppLocalizations.of(context).prefsMaxKm(_max.round()),
                style: AppTextStyles.micro,
              ),
            ],
          ),
          const SizedBox(height: 22),
          EyebrowLabel(AppLocalizations.of(context).prefsAppLanguage),
          const SizedBox(height: 10),
          Row(
            children: [
              _LangPill(
                label: 'English',
                active: _lang == 'en',
                style: (c) =>
                    AppTextStyles.label.copyWith(fontSize: 14, color: c),
                onTap: () => setState(() => _lang = 'en'),
              ),
              const SizedBox(width: 8),
              _LangPill(
                label: 'العربية',
                active: _lang == 'ar',
                style: (c) => arabicStyle(c, size: 18, weight: FontWeight.w600),
                onTap: () => setState(() => _lang = 'ar'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Sits right above the Save button that failed.
          if (_error != null)
            InlineBanner(
              tone: BannerTone.danger,
              icon: LucideIcons.circleAlert,
              body: _error,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String label;
  final bool active;
  final TextStyle Function(Color) style;
  final VoidCallback onTap;

  const _LangPill({
    required this.label,
    required this.active,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppTheme.dur2,
            curve: AppTheme.easeSoft,
            height: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? AppColors.plum700 : AppColors.paper,
              borderRadius: BorderRadius.circular(AppTheme.radius14),
              border: Border.all(
                color: active ? Colors.transparent : AppColors.divider,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: style(active ? AppColors.bone : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}
