import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AiwaIconButtonVariant { paper, plum, rose, glass }

/// Round icon button — mirrors `IconBtn` in the design kit.
class AiwaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final AiwaIconButtonVariant variant;
  final bool dot;
  final Color? iconColor;

  const AiwaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.variant = AiwaIconButtonVariant.paper,
    this.dot = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    Border? border;
    switch (variant) {
      case AiwaIconButtonVariant.paper:
        bg = AppColors.paper;
        fg = AppColors.plum700;
        border = Border.all(color: AppColors.divider);
        break;
      case AiwaIconButtonVariant.plum:
        bg = AppColors.plum700;
        fg = AppColors.paper;
        break;
      case AiwaIconButtonVariant.rose:
        bg = AppColors.rose500;
        fg = AppColors.plum900;
        break;
      case AiwaIconButtonVariant.glass:
        bg = Colors.white.withOpacity(0.85);
        fg = AppColors.plum700;
        border = Border.all(color: AppColors.divider.withOpacity(0.7));
        break;
    }
    final shadow =
        variant == AiwaIconButtonVariant.paper ||
            variant == AiwaIconButtonVariant.glass
        ? [
            BoxShadow(
              color: AppColors.plum700.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ]
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: border,
          boxShadow: shadow,
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: (size * 0.45).roundToDouble(),
              color: iconColor ?? fg,
            ),
            if (dot)
              Positioned(
                top: size * 0.15,
                right: size * 0.18,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.rose500,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.paper, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
