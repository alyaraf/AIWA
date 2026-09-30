import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/press_scale.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Splash — brand hero + language picker + "Browse as guest".
/// Signed-in users are routed straight past it.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // aiwa-slide-in: translateX 8% -> 0, 320ms soft.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppTheme.dur3,
  )..forward();
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0.08, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: AppTheme.easeSoft)).animate(_controller);

  /// Hidden only while a stored session is being checked (AuthInitial);
  /// the bloc always leaves AuthInitial, even when the check throws.
  late bool _showChoices = context.read<AuthBloc>().state is! AuthInitial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pickLanguage(String code, {bool guest = false}) {
    LocaleController.set(code);
    if (guest) {
      context.go(AppRoutes.home);
    } else {
      context.push(AppRoutes.roleChoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, _) => ModalRoute.of(context)?.isCurrent ?? false,
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.landingFor(state.user));
        } else if (state is! AuthInitial && !_showChoices) {
          setState(() => _showChoices = true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.plum900,
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.heroGradient),
          child: Stack(
            children: [
              // prototype.jsx:51 — circle at 30% 25% (.5, transparent 55%)
              // and at 75% 80% (.3, transparent 60%).
              Positioned.fill(
                child: AiwaGlow.fill(
                  center: const Alignment(-.4, -.5),
                  color: AppColors.glowRose,
                  opacity: .5,
                  stop: .55,
                ),
              ),
              Positioned.fill(
                child: AiwaGlow.fill(
                  center: const Alignment(.5, .6),
                  color: AppColors.glowGold,
                  opacity: .3,
                  stop: .6,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  insets.top + 40,
                  28,
                  insets.bottom + 34,
                ),
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      AiwaWordmark(
                        size: 56,
                        color: AppColors.bone,
                        dotColor: AppColors.rose500,
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          AppLocalizations.of(context).authTagline,
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.bone,
                            fontSize: 34,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          AppLocalizations.of(context).authTaglineSub,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.rose300,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: AppTheme.dur3,
                        switchInCurve: AppTheme.easeSoft,
                        child: _showChoices
                            ? _buildChoices()
                            : const SizedBox(height: 160),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Column(
      key: const ValueKey('choices'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EyebrowLabel(
          AppLocalizations.of(context).authChooseLanguage,
          color: AppColors.rose300,
        ),
        const SizedBox(height: 14),
        _LanguageButton(
          label: 'English',
          filled: true,
          onTap: () => _pickLanguage('en'),
        ),
        const SizedBox(height: 10),
        _LanguageButton(
          label: 'العربية',
          arabic: true,
          onTap: () => _pickLanguage('ar'),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => _pickLanguage(
              LocaleController.locale.value.languageCode,
              guest: true,
            ),
            child: Text(
              AppLocalizations.of(context).authBrowseAsGuest,
              style: AppTextStyles.label.copyWith(color: AppColors.rose300),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool arabic;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.arabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.plum900 : AppColors.bone;
    final text = Text(
      label,
      style: arabic
          ? arabicStyle(fg)
          : AppTextStyles.button.copyWith(color: fg),
    );
    // Each button lays itself out in its own language's direction.
    final arrow = Icon(LucideIcons.arrowRightDir, size: 18, color: fg);
    return Directionality(
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            color: filled ? AppColors.bone : AppColors.bone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: filled
                ? null
                : Border.all(color: AppColors.bone.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [text, arrow],
          ),
        ),
      ),
    );
  }
}

/// Markazi Text for the Arabic language buttons (native pubspec family).
TextStyle arabicStyle(
  Color color, {
  double size = 20,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: kArabicSerif,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1,
);
