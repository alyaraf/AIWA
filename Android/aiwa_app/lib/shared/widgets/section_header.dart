import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'press_scale.dart';

/// Serif section title with an optional text action — includes the kit's
/// 22px top / 12px bottom rhythm, so callers don't add their own spacing.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.gutter,
      22,
      AppTheme.gutter,
      12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(title, style: AppTextStyles.h3.copyWith(height: 1.1)),
          ),
          if (action != null)
            PressScale(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  action!,
                  style: AppTextStyles.label.copyWith(color: AppColors.plum700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
