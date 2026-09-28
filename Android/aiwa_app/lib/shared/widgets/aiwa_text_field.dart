import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'package:aiwa_app/l10n/l10n.dart';

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

  /// Account-setup style (auth-screens.jsx:335): the input stays idle, the
  /// error is a plain line without icon, and the hint still shows below it.
  final bool inlineError;

  /// Rendered between the input and the error/hint (e.g. strength meter).
  final Widget? belowInput;

  /// Input text style; defaults to body 15 ink.
  final TextStyle? textStyle;

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
    this.inlineError = false,
    this.belowInput,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    final style =
        textStyle ?? AppTextStyles.body.copyWith(color: AppColors.ink);
    final flagInput = hasError && !inlineError;
    // ValidatedInput error state (states.jsx:189-199): danger leading icon
    // plus a trailing circle-alert.
    final prefix =
        prefixIcon ??
        (icon != null
            ? Icon(
                icon,
                size: 17,
                color: flagInput ? AppColors.danger500 : AppColors.plum700,
              )
            : null);

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
                  AppLocalizations.of(context).commonOptional,
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
          style: style,
          cursorColor: AppColors.plum700,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: style.copyWith(color: AppColors.ink4),
            prefixIcon: prefix != null
                ? Padding(
                    // M3 adds a 4px prefix-to-input gap; 6 + 4 = the kit's 10.
                    padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
                    child: prefix,
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon:
                suffixIcon ??
                (flagInput
                    ? Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.danger500,
                      )
                    : null),
            filled: true,
            fillColor: enabled ? AppColors.paper : AppColors.cream,
            border: AppTheme.inputBorder(AppColors.divider),
            enabledBorder: AppTheme.inputBorder(
              flagInput ? AppColors.danger500 : AppColors.divider,
            ),
            disabledBorder: AppTheme.inputBorder(AppColors.divider),
            focusedBorder: AppTheme.inputBorder(
              flagInput ? AppColors.danger500 : AppColors.plum700,
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
        ?belowInput,
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              if (!inlineError) ...[
                Icon(
                  Icons.error_outline_rounded,
                  size: 12,
                  color: AppColors.danger700,
                ),
                const SizedBox(width: 4),
              ],
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
        ],
        if ((!hasError || inlineError) &&
            (hint != null || (showCounter && maxLength != null))) ...[
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (_, v, _) => Text(
                    '${v.text.length}/$maxLength',
                    style: AppTextStyles.mono.copyWith(
                      fontSize: 11,
                      color: AppColors.ink4,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Passes [error] to [builder] only once the field has lost focus —
/// `ValidatedInput`'s touched-on-blur rule.
class ValidatedField extends StatefulWidget {
  final String? error;
  final Widget Function(String? error) builder;
  const ValidatedField({super.key, required this.error, required this.builder});

  @override
  State<ValidatedField> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends State<ValidatedField> {
  bool _touched = false;

  @override
  Widget build(BuildContext context) => Focus(
    skipTraversal: true,
    onFocusChange: (f) {
      if (!f && !_touched) setState(() => _touched = true);
    },
    child: widget.builder(_touched ? widget.error : null),
  );
}
