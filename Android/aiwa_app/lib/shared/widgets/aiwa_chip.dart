import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Pill chip — mirrors `Chip` in the design kit (default / active / tonal).
class AiwaChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool tonal;
  final IconData? icon;
  final VoidCallback? onTap;

  const AiwaChip({
    super.key,
    required this.label,
    this.active = false,
    this.tonal = false,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.paper;
    Color fg = AppColors.ink2;
    Color border = AppColors.divider;
    if (active) {
      bg = AppColors.plum700;
      fg = AppColors.paper;
      border = Colors.transparent;
    } else if (tonal) {
      bg = AppColors.plum100;
      fg = AppColors.plum700;
      border = Colors.transparent;
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        curve: AppTheme.easeSoft,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fg,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
