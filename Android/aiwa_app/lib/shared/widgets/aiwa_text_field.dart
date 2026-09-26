import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Labelled input — mirrors `Field` + `TextInput` in the design kit:
/// eyebrow label, optional tag, hint underneath, per-field error with icon.
class AiwaTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? placeholder;
  final String? error;
  final bool optional;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? icon;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final bool showCounter;
  final TextInputAction? textInputAction;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autoFocus;
  final bool enabled;

  const AiwaTextField({
    super.key,
    this.label,
    this.hint,
    this.placeholder,
    this.error,
    this.optional = false,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autoFocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final prefix =
        prefixIcon ??
        (icon != null ? Icon(icon, size: 17, color: AppColors.plum700) : null);
    final hasError = error != null && error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(label!.toUpperCase(), style: AppTextStyles.eyebrow),
              ),
              if (optional)
                Text(
                  'Optional',
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          autofocus: autoFocus,
          enabled: enabled,
          style: AppTextStyles.body.copyWith(color: AppColors.ink),
          cursorColor: AppColors.plum700,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink4),
            prefixIcon: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: prefix,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? AppColors.paper : AppColors.cream,
            border: AppTheme.inputBorder(AppColors.divider),
            enabledBorder: AppTheme.inputBorder(
              hasError ? AppColors.danger500 : AppColors.divider,
            ),
            disabledBorder: AppTheme.inputBorder(AppColors.divider),
            focusedBorder: AppTheme.inputBorder(
              hasError ? AppColors.danger500 : AppColors.plum700,
            ),
            errorBorder: AppTheme.inputBorder(AppColors.danger500),
            focusedErrorBorder: AppTheme.inputBorder(AppColors.danger500),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: (maxLines ?? 1) > 1 ? 14 : 13,
            ),
            counterText: '',
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 12,
                color: AppColors.danger700,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  error!,
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 11.5,
                    color: AppColors.danger700,
                  ),
                ),
              ),
            ],
          ),
        ] else if (hint != null || (showCounter && maxLength != null)) ...[
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: hint != null
                    ? Text(
                        hint!,
                        style: AppTextStyles.micro.copyWith(fontSize: 11.5),
                      )
                    : const SizedBox.shrink(),
              ),
              if (showCounter && maxLength != null && controller != null)
                Text(
                  '${controller!.text.length}/$maxLength',
                  style: AppTextStyles.micro,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
