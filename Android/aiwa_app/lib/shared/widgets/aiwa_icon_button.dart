import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'press_scale.dart';

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

    Widget button = Container(
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
            PositionedDirectional(
              top: size * 0.15,
              end: size * 0.18,
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
    );
    if (variant == AiwaIconButtonVariant.glass) {
      // backdropFilter: blur(8px) (components.jsx:80).
      button = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: button,
        ),
      );
    }
    return PressScale(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: button,
    );
  }
}
