import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../../../shared/widgets/screen_chrome.dart';

class ProviderPendingPage extends StatelessWidget {
  const ProviderPendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.plum900,
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            Positioned(
              left: -60,
              top: 40,
              child: AiwaGlow(
                size: 340,
                color: AppColors.rose300,
                opacity: 0.4,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                28,
                insets.top + 28,
                28,
                insets.bottom + 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: 34,
                      color: AppColors.bone,
                    ),
                  ),
                  const SizedBox(height: 22),
                  EyebrowLabel(
                    'Verification submitted',
                    color: AppColors.rose300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We're reviewing\nyour documents.",
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
                        children: [
                          const TextSpan(text: 'Most reviews take '),
                          TextSpan(
                            text: 'under 24 hours',
                            style: TextStyle(
                              color: AppColors.bone,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text:
                                ". You'll get a notification the moment AIWA approves your studio — then you can take bookings.",
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _StatusRow(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'ID front & back received',
                    color: AppColors.rose300,
                  ),
                  const SizedBox(height: 10),
                  _StatusRow(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'Live selfie received',
                    color: AppColors.rose300,
                  ),
                  const SizedBox(height: 10),
                  _StatusRow(
                    icon: Icons.hourglass_top_rounded,
                    text: 'Admin review in progress',
                    color: AppColors.gold300,
                  ),
                  const Spacer(),
                  AiwaButton(
                    label: 'Explore the app while you wait',
                    variant: AiwaButtonVariant.accent,
                    fullWidth: true,
                    size: AiwaButtonSize.lg,
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'You can browse, but bookings open after verification.',
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 11.5,
                        color: AppColors.rose300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
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
        borderRadius: BorderRadius.circular(12),
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
