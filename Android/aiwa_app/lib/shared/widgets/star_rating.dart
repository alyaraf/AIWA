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
      children: List.generate(5, (i) {
        final filled = i < value.floor();
        final halfFilled =
            !filled && i < value && (value - value.floor()) >= 0.5;
        final color = activeColor ?? AppColors.gold500;
        final emptyColor = inactiveColor ?? AppColors.divider;
        return Icon(
          halfFilled
              ? Icons.star_half_rounded
              : filled
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: (filled || halfFilled) ? color : emptyColor,
        );
      }),
    );
  }
}
