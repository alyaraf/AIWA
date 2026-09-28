import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../widgets/step_header.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Terms & safety policy — `TermsScreen` in flow-screens.jsx. Acceptance is
/// sent with the account creation at the end of Preferences.
class TermsPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;
  const TermsPage({super.key, required this.registrationData});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = [
      (
        LucideIcons.shieldCheck,
        l.authTermsVerifiedTitle,
        l.authTermsVerifiedBody,
      ),
      (LucideIcons.lock, l.authTermsPrivateTitle, l.authTermsPrivateBody),
      (LucideIcons.flag, l.authTermsFlagTitle, l.authTermsFlagBody),
      (LucideIcons.banknote, l.authTermsCashTitle, l.authTermsCashBody),
    ];
    final strong = TextStyle(
      color: AppColors.plum700,
      fontWeight: FontWeight.w600,
    );
    return AuthStepScaffold(
      bottom: AiwaButton(
        label: l.authAgreeContinue,
        size: AiwaButtonSize.lg,
        fullWidth: true,
        onPressed: _agree
            ? () => context.push(
                AppRoutes.preferences,
                extra: widget.registrationData,
              )
            : null,
      ),
      children: [
        AiwaIconButton(
          icon: LucideIcons.arrowLeftDir,
          onTap: () => context.pop(),
        ),
        const SizedBox(height: 22),
        EyebrowLabel(l.authStepOf(1, 2)),
        const SizedBox(height: 6),
        Text(
          l.authTermsTitle,
          style: AppTextStyles.h1.copyWith(
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.authTermsSubtitle,
          style: AppTextStyles.bodySm.copyWith(
            fontSize: 14,
            color: AppColors.ink2,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        for (final (icon, title, text) in sections) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.plum100,
                    borderRadius: BorderRadius.circular(AppTheme.radius10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.plum700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.label.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        text,
                        style: AppTextStyles.bodySm.copyWith(
                          fontSize: AppTextStyles.fsLabelSmPlus,
                          color: AppColors.ink2,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 4),
        Semantics(
          checked: _agree,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _agree = !_agree),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: AppTheme.dur2,
                  curve: AppTheme.easeSoft,
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _agree ? AppColors.plum700 : AppColors.ink4,
                      width: 2,
                    ),
                    color: _agree ? AppColors.plum700 : Colors.transparent,
                  ),
                  child: _agree
                      ? const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children:
                          spansOf(l.authTermsAgree('{terms}', '{policy}'), {
                            'terms': TextSpan(
                              text: l.authCustomerTermsLink,
                              style: strong,
                            ),
                            'policy': TextSpan(
                              text: l.authSafetyPolicyLink,
                              style: strong,
                            ),
                          }),
                    ),
                    style: AppTextStyles.bodySm.copyWith(
                      fontSize: 13,
                      color: AppColors.ink2,
                      height: 1.5,
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
