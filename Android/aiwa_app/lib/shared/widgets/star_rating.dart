import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StarRating extends StatelessWidget {
  final double value;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const StarRating({
    super.key,
    required this.value,
    this.size = 14,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 1,
      children: List.generate(5, (i) {
        // Integer fill like the kit (`n <= value`): 4.8 shows 4 stars.
        final filled = i + 1 <= value;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled
              ? activeColor ?? AppColors.gold500
              : inactiveColor ?? AppColors.ink4,
        );
      }),
    );
  }
}
