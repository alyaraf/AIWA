import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

/// Splash — brand hero + language picker + "Browse as guest".
/// Signed-in users are routed straight past it.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppTheme.easeSoft,
  );

  bool _showChoices = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is AuthUnauthenticated || state is AuthError) {
      _showChoices = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickLanguage(String code, {bool guest = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aiwa_language', code);
    } catch (_) {}
    if (!mounted) return;
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
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(
            state.user.isProvider
                ? AppRoutes.providerDashboard
                : AppRoutes.home,
          );
        } else if (state is AuthUnauthenticated || state is AuthError) {
          setState(() => _showChoices = true);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.plum900,
        body: Container(
          decoration: BoxDecoration(gradient: AppTheme.heroGradient),
          child: Stack(
            children: [
              // Soft radial highlights
              Positioned(
                left: -80,
                top: -40,
                child: AiwaGlow(
                  size: 360,
                  color: AppColors.rose300,
                  opacity: 0.35,
                ),
              ),
              Positioned(
                right: -90,
                bottom: 60,
                child: AiwaGlow(
                  size: 300,
                  color: AppColors.gold300,
                  opacity: 0.22,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  insets.top + 40,
                  28,
                  insets.bottom + 34,
                ),
                child: FadeTransition(
                  opacity: _fade,
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
                          'Beauty & grooming, near you.',
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
                          'Trusted barbers, hairdressers, nail artists, and spas — one tap away.',
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
        EyebrowLabel('Choose your language', color: AppColors.rose300),
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
            onTap: () => _pickLanguage('en', guest: true),
            child: Text(
              'Browse as guest →',
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
          ? _arabicStyle(fg)
          : AppTextStyles.button.copyWith(color: fg),
    );
    final arrow = Icon(
      arabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
      size: 18,
      color: fg,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? AppColors.bone : AppColors.bone.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: filled
              ? null
              : Border.all(color: AppColors.bone.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: arabic ? [arrow, text] : [text, arrow],
        ),
      ),
    );
  }
}

/// Markazi Text for the Arabic language button (plain family in tests).
TextStyle _arabicStyle(Color color) {
  if (aiwaUseGoogleFonts) {
    return GoogleFonts.markaziText(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1,
    );
  }
  return TextStyle(
    fontFamily: 'Markazi Text',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1,
  );
}
