import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';

/// Soft gate shown when a guest tries to book — `AuthGateScreen` in the kit.
class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    const perks = [
      'Your booking history in one place',
      'Live status + safety tracking',
      'Save favorite providers',
    ];
    return AuthStepScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AiwaButton(
            label: 'Create account',
            fullWidth: true,
            size: AiwaButtonSize.lg,
            onPressed: () =>
                context.push(AppRoutes.phoneEntry, extra: {'role': 'CUSTOMER'}),
          ),
          const SizedBox(height: 10),
          AiwaButton(
            label: 'I already have an account',
            variant: AiwaButtonVariant.secondary,
            fullWidth: true,
            size: AiwaButtonSize.lg,
            onPressed: () => context.push('${AppRoutes.signIn}?role=CUSTOMER'),
          ),
        ],
      ),
      children: [
        AiwaIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: 22),
        EyebrowLabel('One quick step', color: AppColors.rose700),
        const SizedBox(height: 6),
        Text(
          'Sign in to book.',
          style: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.05),
        ),
        const SizedBox(height: 8),
        Text(
          'Browsing is open to everyone. Booking needs an account so providers can reach you.',
          style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
        ),
        const SizedBox(height: 26),
        ...perks.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.check_rounded, size: 14, color: AppColors.plum700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t,
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 13.5,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
