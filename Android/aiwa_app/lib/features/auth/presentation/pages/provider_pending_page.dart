import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart' show AiwaGlow;
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProviderPendingPage extends StatelessWidget {
  const ProviderPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.plum900,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            // radial-gradient(circle at 30% 25%, rose .45, transparent 60%).
            Positioned.fill(
              child: AiwaGlow.fill(
                center: const Alignment(-.4, -.5),
                color: AppColors.rose300,
                opacity: .45,
                stop: .6,
              ),
            ),
            // Scrolls on short screens / large text; Spacers still centre.
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  28,
                  insets.top + 28,
                  28,
                  math.max(40, insets.bottom + 6),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(
                      0,
                      c.maxHeight -
                          insets.top -
                          28 -
                          math.max(40, insets.bottom + 6),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius22,
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius22,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: Icon(
                                LucideIcons.hourglass,
                                size: 34,
                                color: AppColors.bone,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        EyebrowLabel(
                          l.provPendingEyebrow,
                          color: AppColors.rose300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.provPendingTitle,
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.bone,
                            fontSize: 34,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text.rich(
                            TextSpan(
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.rose300,
                                height: 1.6,
                              ),
                              children:
                                  spansOf(l.provPendingBody('{duration}'), {
                                    'duration': TextSpan(
                                      text: l.provPendingUnder24h,
                                      style: TextStyle(
                                        color: AppColors.bone,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _StatusRow(
                          icon: LucideIcons.circleCheck,
                          text: l.provPendingIdReceived,
                          color: AppColors.rose300,
                        ),
                        const SizedBox(height: 10),
                        _StatusRow(
                          icon: LucideIcons.circleCheck,
                          text: l.provPendingSelfieReceived,
                          color: AppColors.rose300,
                        ),
                        const SizedBox(height: 10),
                        _StatusRow(
                          icon: LucideIcons.hourglass,
                          text: l.provPendingAdminReview,
                          color: AppColors.gold300,
                        ),
                        const Spacer(),
                        AiwaButton(
                          label: l.provPendingExplore,
                          variant: AiwaButtonVariant.accent,
                          fullWidth: true,
                          size: AiwaButtonSize.lg,
                          onPressed: () => context.go(AppRoutes.home),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            l.provPendingBrowseNote,
                            style: AppTextStyles.micro.copyWith(
                              fontSize: AppTextStyles.fsMicroPlus,
                              color: AppColors.rose300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(
                color: AppColors.bone,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
