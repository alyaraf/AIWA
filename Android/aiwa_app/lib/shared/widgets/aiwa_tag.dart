import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Small pill label — `Tag` in states.jsx:397-410. Only the tones in use.
class AiwaTag extends StatelessWidget {
  final String label;
  final bool neutral;
  const AiwaTag(this.label, {super.key, this.neutral = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? AppColors.cream : AppColors.plum100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: neutral ? AppColors.ink3 : AppColors.plum700,
        ),
      ),
    );
  }
}
