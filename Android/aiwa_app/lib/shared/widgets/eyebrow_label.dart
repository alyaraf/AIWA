import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Uppercase 11px / 0.14em label — `Eyebrow` in the kit.
class EyebrowLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final TextAlign? textAlign;

  const EyebrowLabel(
    this.text, {
    super.key,
    this.color,
    this.fontSize,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final size = fontSize ?? 11;
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: AppTextStyles.eyebrow.copyWith(
        color: color ?? AppColors.ink3,
        fontSize: size,
        letterSpacing: 0.14 * size,
        height: 1.2,
      ),
    );
  }
}
