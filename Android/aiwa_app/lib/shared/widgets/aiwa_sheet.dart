import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'eyebrow_label.dart';

/// Bone bottom sheet with the 40x4 handle, padding 18/22/34 and the plum
/// scrim — the frame of SlotConflictSheet / BookNowCheckSheet.
Future<T?> showAiwaSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double handleGap = 16,
  double bottom = 34,
  // .48 ConfirmSheet-style, .45 for CancelSheet (flow-screens.jsx:505).
  double scrim = .48,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  barrierColor: AppColors.plum900.withValues(alpha: scrim),
  isScrollControlled: true,
  // Blocking sheets (e.g. while checking) wrap their body in PopScope.
  enableDrag: false,
  builder: (ctx) => Container(
    decoration: AppTheme.sheetDecoration,
    padding: EdgeInsets.fromLTRB(
      22,
      18,
      22,
      // The kit's bottom padding already includes the home indicator.
      math.max(bottom, MediaQuery.paddingOf(ctx).bottom),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        SizedBox(height: handleGap),
        builder(ctx),
      ],
    ),
  ),
);

/// Warn icon circle + eyebrow + serif title + body used by the blocking
/// sheets (system-screens.jsx:160-164, 263-268).
class SheetWarnHead extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;

  const SheetWarnHead({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.warn100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: AppColors.warn700),
        ),
        const SizedBox(height: 12),
        EyebrowLabel(eyebrow, color: AppColors.warn700),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTextStyles.h3.copyWith(fontSize: 23, height: 1.12),
        ),
        const SizedBox(height: 7),
        Text(
          body,
          style: AppTextStyles.body.copyWith(
            fontSize: 13.5,
            height: 1.55,
            color: AppColors.ink2,
          ),
        ),
      ],
    );
  }
}
