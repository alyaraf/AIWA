import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_button.dart';
import 'eyebrow_label.dart';
import 'system_screen.dart' show PopIn;
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom-sheet confirm used for every destructive action — `ConfirmSheet`.
///
/// Returns `true` when confirmed. Pass [input] to collect an optional reason;
/// the typed text is written back to that controller.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? eyebrow,
  String? body,
  String? confirmLabel,
  String? cancelLabel,
  bool danger = true,
  IconData? icon,
  TextEditingController? input,
  String? inputHint,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim.withValues(alpha: 0.48),
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(
      duration: AppTheme.dur3,
      curve: AppTheme.easeSoft,
    ),
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
            // states.jsx:234 bottom 34 already includes the home indicator.
            math.max(34, MediaQuery.paddingOf(ctx).bottom),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
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
                          ? LucideIcons.triangleAlert
                          : LucideIcons.circleQuestionMark),
                  size: 21,
                  color: fg,
                ),
              ),
              const SizedBox(height: 12),
              if (eyebrow != null) EyebrowLabel(eyebrow, color: fg),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  fontSize: 23,
                  height: 1.12,
                  letterSpacing: 0,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 7),
                Text(
                  body,
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: AppTextStyles.fsMetaPlus,
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
                      label:
                          cancelLabel ?? AppLocalizations.of(ctx).commonCancel,
                      variant: AiwaButtonVariant.secondary,
                      size: AiwaButtonSize.lg,
                      fullWidth: true,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AiwaButton(
                      label:
                          confirmLabel ??
                          AppLocalizations.of(ctx).commonConfirm,
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

/// Centered success terminal — `SuccessSheet` in states.jsx.
Future<void> showSuccessSheet(
  BuildContext context, {
  required String title,
  String? body,
  String? primary,
  VoidCallback? onPrimary,
  String? secondary,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim.withValues(alpha: 0.48),
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: AppTheme.sheetDecoration,
      padding: EdgeInsets.fromLTRB(
        AppTheme.gutter,
        18,
        AppTheme.gutter,
        24 + MediaQuery.paddingOf(ctx).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
          ),
          const SizedBox(height: 18),
          PopIn(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.success100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.check,
                size: 27,
                color: AppColors.success700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(
              fontSize: 24,
              height: 1.12,
              letterSpacing: 0,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(
                  fontSize: AppTextStyles.fsMetaPlus,
                  color: AppColors.ink2,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AiwaButton(
            label: primary ?? AppLocalizations.of(ctx).commonDone,
            size: AiwaButtonSize.lg,
            fullWidth: true,
            onPressed: onPrimary ?? () => Navigator.pop(ctx),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 9),
            AiwaButton(
              label: secondary,
              variant: AiwaButtonVariant.ghost,
              size: AiwaButtonSize.sm,
              fullWidth: true,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    ),
  );
}

/// "Type DELETE to confirm" — `DeleteAccountSheet` in customer-extras-2.jsx.
/// Returns `true` once the phrase matches and the user confirms.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final text = TextEditingController();
  final l = AppLocalizations.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim.withValues(alpha: .5),
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: Container(
        decoration: AppTheme.sheetDecoration,
        padding: EdgeInsets.fromLTRB(
          AppTheme.gutter,
          18,
          AppTheme.gutter,
          36 + MediaQuery.paddingOf(ctx).bottom,
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
                  borderRadius: BorderRadius.circular(AppTheme.radius2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EyebrowLabel(l.delCantUndo, color: AppColors.danger700),
            const SizedBox(height: 4),
            Text(
              l.delTitle,
              style: AppTextStyles.h3.copyWith(
                fontSize: 22,
                height: 1.1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: spansOf(l.delBody('{phrase}'), {
                  'phrase': TextSpan(
                    text: l.delPhrase,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                }),
              ),
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 13,
                height: 1.5,
                color: AppColors.ink2,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: text,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              cursorColor: AppColors.plum700,
              style: AppTextStyles.mono.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: l.delPhrase,
                hintStyle: AppTextStyles.mono.copyWith(
                  fontSize: 14,
                  color: AppColors.ink4,
                ),
                filled: true,
                fillColor: AppColors.paper,
                border: AppTheme.inputBorder(AppColors.divider),
                enabledBorder: AppTheme.inputBorder(AppColors.divider),
                focusedBorder: AppTheme.inputBorder(AppColors.plum700),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AiwaButton(
                    label: l.commonCancel,
                    variant: AiwaButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: text,
                    builder: (_, v, _) => AiwaButton(
                      label: l.profDeleteAccount,
                      variant: AiwaButtonVariant.danger,
                      fullWidth: true,
                      onPressed: v.text.trim().toUpperCase() == l.delPhrase
                          ? () => Navigator.pop(ctx, true)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  // ponytail: `text` isn't disposed — the sheet still reads it during its
  // exit animation, after this future completes; it holds no resources.
  return result ?? false;
}
