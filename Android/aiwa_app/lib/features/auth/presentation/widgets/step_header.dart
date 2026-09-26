import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_icon_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';

/// Back button + progress segments + "Step n of N" + title — signup flow.
class StepHeader extends StatelessWidget {
  final int step;
  final int total;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiwaIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(height: 18),
        Row(
          children: List.generate(total, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: AppTheme.dur3,
                curve: AppTheme.easeSoft,
                height: 3,
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i < step ? AppColors.plum700 : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        EyebrowLabel('Step $step of $total'),
        const SizedBox(height: 6),
        Text(
          title,
          style: AppTextStyles.h1.copyWith(
            fontSize: 28,
            height: 1.08,
            letterSpacing: -0.02 * 28,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 13.5,
              color: AppColors.ink2,
            ),
          ),
        ],
      ],
    );
  }
}

/// Page scaffold for auth steps: scrollable body + pinned bottom action.
class AuthStepScaffold extends StatelessWidget {
  final List<Widget> children;
  final Widget bottom;
  final bool stickyBar;

  const AuthStepScaffold({
    super.key,
    required this.children,
    required this.bottom,
    this.stickyBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, insets.top + 18, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
          if (stickyBar)
            Container(
              decoration: BoxDecoration(
                color: AppColors.paper,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: EdgeInsets.fromLTRB(22, 14, 22, 14 + insets.bottom),
              child: bottom,
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + insets.bottom),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

/// Phone / Email segmented toggle used on sign-in and phone entry.
class IdentifierModeToggle extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;

  const IdentifierModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        children: ['phone', 'email'].map((m) {
          final active = mode == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: AppTheme.dur2,
                curve: AppTheme.easeSoft,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.paper : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.plum700.withOpacity(0.08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  m == 'phone' ? 'Phone' : 'Email',
                  style: AppTextStyles.label.copyWith(
                    color: active ? AppColors.plum900 : AppColors.ink3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 🇪🇬 +20 prefix + number field.
class EgyptPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autoFocus;

  const EgyptPhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Text(
            '🇪🇬 +20',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: autoFocus,
            onChanged: onChanged,
            cursorColor: AppColors.plum700,
            style: AppTextStyles.body.copyWith(
              color: AppColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: '100 555 8821',
              hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink4),
              filled: true,
              fillColor: AppColors.paper,
              border: AppTheme.inputBorder(AppColors.divider),
              enabledBorder: AppTheme.inputBorder(AppColors.divider),
              focusedBorder: AppTheme.inputBorder(AppColors.plum700),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
