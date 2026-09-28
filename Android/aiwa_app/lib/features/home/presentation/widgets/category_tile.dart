import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';

/// White tile with a tinted icon square — home "Categories" grid.
class CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String palette;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    switch (palette) {
      case 'rose':
        bg = AppColors.rose100;
        fg = AppColors.rose700;
        break;
      case 'gold':
        bg = AppColors.gold100;
        fg = AppColors.gold700;
        break;
      case 'cream':
        bg = AppColors.cream;
        fg = AppColors.plum900;
        break;
      default:
        bg = AppColors.plum100;
        fg = AppColors.plum700;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppTheme.radius14),
              ),
              child: Icon(icon, size: 22, color: fg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
