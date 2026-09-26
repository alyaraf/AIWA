import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';

/// After the role pick: "Create account" vs "I already have an account".
class AuthChoicePage extends StatelessWidget {
  final String role;
  const AuthChoicePage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isProvider = role == 'PROVIDER';
    final eyebrow = isProvider ? 'Provider · Welcome' : 'Customer · Welcome';
    final title = isProvider
        ? 'Run your beauty studio with AIWA.'
        : 'Beauty & grooming, near you.';
    final subtitle = isProvider
        ? 'Manage bookings, hours, and your verified profile — all in one app.'
        : 'Trusted barbers, hairdressers, nail artists, and spas — one tap away.';
    final signUpCta = isProvider ? 'Set up a new studio' : 'Create an account';
    final signUpHint = isProvider
        ? 'ID verification required.'
        : 'Takes about a minute.';
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Stack(
        children: [
          // Decorative top half
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5,
            child: Container(
              decoration: BoxDecoration(gradient: AppTheme.heroGradient),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -60,
                    top: -40,
                    child: AiwaGlow(size: 320, color: AppColors.rose300),
                  ),
                  Positioned(
                    right: -60,
                    bottom: -80,
                    child: AiwaGlow(
                      size: 260,
                      color: AppColors.gold300,
                      opacity: 0.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, insets.top + 12, 24, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height - insets.top - 12,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AiwaIconButton(
                      icon: Icons.arrow_back_rounded,
                      variant: AiwaIconButtonVariant.glass,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.roleChoice),
                    ),
                    const SizedBox(height: 26),
                    EyebrowLabel(eyebrow, color: AppColors.rose300),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        title,
                        style: AppTextStyles.h1.copyWith(
                          color: AppColors.bone,
                          fontSize: 32,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        subtitle,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.rose300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                    _ChoiceCard(
                      icon: isProvider
                          ? Icons.work_outline_rounded
                          : Icons.auto_awesome_outlined,
                      iconBg: AppColors.plum700,
                      iconFg: AppColors.bone,
                      title: signUpCta,
                      subtitle: signUpHint,
                      shadow: true,
                      onTap: () => context.push(
                        AppRoutes.phoneEntry,
                        extra: {'role': role},
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceCard(
                      icon: Icons.login_rounded,
                      iconBg: AppColors.plum100,
                      iconFg: AppColors.plum700,
                      title: 'I already have an account',
                      subtitle: 'Sign in with phone or email.',
                      onTap: () =>
                          context.push('${AppRoutes.signIn}?role=$role'),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 13,
                          color: AppColors.plum700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Protected by AIWA's safety policy",
                          style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                    SizedBox(height: 16 + insets.bottom),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconFg;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool shadow;

  const _ChoiceCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: shadow ? AppTheme.shadow3 : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(fontSize: 20, height: 1.1),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppTextStyles.meta.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.plum700,
            ),
          ],
        ),
      ),
    );
  }
}
