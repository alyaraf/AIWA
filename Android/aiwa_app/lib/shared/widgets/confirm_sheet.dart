import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_button.dart';
import 'eyebrow_label.dart';

/// Bottom-sheet confirm used for every destructive action — `ConfirmSheet`.
///
/// Returns `true` when confirmed. Pass [input] to collect an optional reason;
/// the typed text is written back to that controller.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? eyebrow,
  String? body,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool danger = true,
  IconData? icon,
  TextEditingController? input,
  String? inputHint,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.plum900.withOpacity(0.48),
    isScrollControlled: true,
    builder: (ctx) {
      final fg = danger ? AppColors.danger700 : AppColors.plum700;
      final bg = danger ? AppColors.danger100 : AppColors.plum100;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: AppTheme.sheetDecoration,
          padding: EdgeInsets.fromLTRB(
            AppTheme.gutter,
            18,
            AppTheme.gutter,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(
                  icon ??
                      (danger
                          ? Icons.warning_amber_rounded
                          : Icons.help_outline_rounded),
                  size: 21,
                  color: fg,
                ),
              ),
              const SizedBox(height: 12),
              if (eyebrow != null) EyebrowLabel(eyebrow, color: fg),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.h3.copyWith(fontSize: 23, height: 1.12),
              ),
              if (body != null) ...[
                const SizedBox(height: 7),
                Text(
                  body,
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: 13.5,
                    color: AppColors.ink2,
                  ),
                ),
              ],
              if (input != null) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: input,
                  maxLines: 2,
                  cursorColor: AppColors.plum700,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: inputHint,
                    filled: true,
                    fillColor: AppColors.paper,
                    border: AppTheme.inputBorder(AppColors.divider),
                    enabledBorder: AppTheme.inputBorder(AppColors.divider),
                    focusedBorder: AppTheme.inputBorder(AppColors.plum700),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AiwaButton(
                      label: cancelLabel,
                      variant: AiwaButtonVariant.secondary,
                      size: AiwaButtonSize.lg,
                      fullWidth: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AiwaButton(
                      label: confirmLabel,
                      variant: danger
                          ? AiwaButtonVariant.danger
                          : AiwaButtonVariant.primary,
                      size: AiwaButtonSize.lg,
                      fullWidth: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
