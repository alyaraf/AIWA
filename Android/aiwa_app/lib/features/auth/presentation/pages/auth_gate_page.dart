import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// Soft gate shown when a guest tries to book — `AuthGateScreen` in the kit.
///
/// [returnTo] is the booking step the guest was heading to; after signing in
/// (or up) the booking resumes there instead of landing on Home.
class AuthGatePage extends StatelessWidget {
  final String? returnTo;
  const AuthGatePage({super.key, this.returnTo});

  Future<void> _signIn(BuildContext context) async {
    if (returnTo == null) {
      context.push('${AppRoutes.signIn}?role=CUSTOMER');
      return;
    }
    final ok = await context.push<bool>(
      '${AppRoutes.signIn}?role=CUSTOMER&resume=1',
    );
    if (ok == true && context.mounted) context.pushReplacement(returnTo!);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final perks = [
      l.authGatePerkHistory,
      l.authGatePerkTracking,
      l.authGatePerkFavorites,
    ];
    return AuthStepScaffold(
      topGap: 23,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AiwaButton(
            label: l.authCreateAccount,
            fullWidth: true,
            size: AiwaButtonSize.lg,
            onPressed: () {
              AppRoutes.resumeAfterSignUp = returnTo;
              context.push(AppRoutes.phoneEntry, extra: {'role': 'CUSTOMER'});
            },
          ),
          const SizedBox(height: 10),
          AiwaButton(
            label: l.authHaveAccount,
            variant: AiwaButtonVariant.secondary,
            fullWidth: true,
            size: AiwaButtonSize.lg,
            onPressed: () => _signIn(context),
          ),
        ],
      ),
      children: [
        AiwaIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: 22),
        EyebrowLabel(l.authGateEyebrow, color: AppColors.rose700),
        const SizedBox(height: 6),
        Text(
          l.authGateTitle,
          style: AppTextStyles.h1.copyWith(
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.authGateBody,
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
