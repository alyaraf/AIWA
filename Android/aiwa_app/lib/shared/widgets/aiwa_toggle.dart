import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 42x24 switch — `Toggle` in states.jsx. [warn] swaps the on colour.
class AiwaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool warn;

  const AiwaToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: AppTheme.dur2,
          curve: AppTheme.easeSoft,
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? (warn ? AppColors.warn500 : AppColors.plum700)
                : AppColors.divider,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          child: AnimatedAlign(
            duration: AppTheme.dur2,
            curve: AppTheme.easeSoft,
            alignment: value
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.scrim.withValues(alpha: .25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
