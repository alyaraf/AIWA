import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_button.dart';
import 'aiwa_sheet.dart';
import 'eyebrow_label.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Pick-a-reason bottom sheet — `CancelSheet` (flow-screens.jsx:490-549).
/// Picking [otherLabel] reveals an optional note (null: never). Confirm
/// needs a reason.
Future<({String reason, String note})?> showReasonSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required List<String> reasons,
  String? otherLabel,
  String? notePlaceholder,
  String? cancelLabel,
  String? confirmLabel,
  Color? eyebrowColor,

  /// danger100 note under the title (ProviderCancelSheet's penalty warning).
  String? warning,
}) => showAiwaSheet(
  context,
  handleGap: 14,
  bottom: 36,
  scrim: .45,
  builder: (_) => _ReasonSheet(
    eyebrow: eyebrow,
    title: title,
    reasons: reasons,
    otherLabel: otherLabel,
    notePlaceholder:
        notePlaceholder ?? AppLocalizations.of(context).reasonNotePlaceholder,
    cancelLabel: cancelLabel ?? AppLocalizations.of(context).reasonKeepBooking,
    confirmLabel: confirmLabel ?? AppLocalizations.of(context).commonCancel,
    eyebrowColor: eyebrowColor,
    warning: warning,
  ),
);

class _ReasonSheet extends StatefulWidget {
  final String eyebrow, title, notePlaceholder;
  final String? otherLabel;
  final String cancelLabel, confirmLabel;
  final List<String> reasons;
  final Color? eyebrowColor;
  final String? warning;

  const _ReasonSheet({
    this.eyebrowColor,
    this.warning,
    required this.eyebrow,
    required this.title,
    required this.reasons,
    required this.otherLabel,
    required this.notePlaceholder,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EyebrowLabel(widget.eyebrow, color: widget.eyebrowColor),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: AppTextStyles.h3.copyWith(
              fontSize: 22,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
          if (widget.warning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger100,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      LucideIcons.triangleAlert,
                      size: 14,
                      color: AppColors.danger700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.warning!,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: AppTextStyles.fsLabelSmPlus,
                        height: 1.5,
                        color: AppColors.danger700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (final r in widget.reasons) ...[
            ReasonRow(
              label: r,
              selected: _reason == r,
              onTap: () => setState(() => _reason = r),
            ),
            const SizedBox(height: 8),
          ],
          if (_reason == widget.otherLabel) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 3,
              cursorColor: AppColors.plum700,
              style: AppTextStyles.bodySm.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.notePlaceholder,
                hintStyle: AppTextStyles.bodySm.copyWith(
                  fontSize: 13,
                  color: AppColors.ink4,
                ),
                filled: true,
                fillColor: AppColors.paper,
                contentPadding: const EdgeInsets.all(12),
                border: AppTheme.inputBorder(AppColors.divider),
                enabledBorder: AppTheme.inputBorder(AppColors.divider),
                focusedBorder: AppTheme.inputBorder(AppColors.plum700),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AiwaButton(
                  label: widget.cancelLabel,
                  variant: AiwaButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AiwaButton(
                  label: widget.confirmLabel,
                  variant: AiwaButtonVariant.danger,
                  fullWidth: true,
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(context, (
                          reason: _reason!,
                          note: _note.text.trim(),
                        )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selectable row: plum100 + 1.5px plum700 border and a check when on.
class ReasonRow extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const ReasonRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: icon == null ? 13 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum100 : AppColors.paper,
          borderRadius: BorderRadius.circular(icon == null ? 12 : 14),
          border: Border.all(
            color: selected ? AppColors.plum700 : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? AppColors.plum700 : AppColors.plum100,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.bone : AppColors.plum700,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySm.copyWith(
                      height: 1.3,
                      fontWeight: icon == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: selected && icon == null
                          ? AppColors.plum900
                          : AppColors.ink,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      hint!,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: AppTextStyles.fsMicroPlus,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(LucideIcons.check, size: 16, color: AppColors.plum700),
          ],
        ),
      ),
    );
  }
}
