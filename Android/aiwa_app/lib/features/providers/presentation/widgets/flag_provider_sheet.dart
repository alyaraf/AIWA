import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/aiwa_text_field.dart';
import '../../../../shared/widgets/aiwa_toast.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../domain/repositories/provider_repository.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Report a provider — `FlagProviderSheet` in customer-extras.jsx.
/// Sends POST /complaints; on success pops and shows the thank-you toast.
Future<void> showFlagProviderSheet(
  BuildContext context, {
  required String providerId,
  required String providerName,
}) {
  final l = AppLocalizations.of(context);
  final reasons = [
    l.flagReasonMisleading,
    l.flagReasonBehavior,
    l.flagReasonPrice,
    l.flagReasonIdentity,
    l.flagReasonSpam,
    l.flagReasonOther,
  ];
  final note = TextEditingController();
  String? reason;
  String? error;
  var sending = false;

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.plum900.withValues(alpha: .45),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Future<void> submit() async {
          setSheet(() {
            sending = true;
            error = null;
          });
          final result = await sl<ProviderRepository>().flagProvider(
            providerId,
            reason!,
            note.text,
          );
          if (!ctx.mounted) return;
          result.fold(
            (f) => setSheet(() {
              sending = false;
              error = l.error(f.message);
            }),
            (_) {
              Navigator.pop(ctx);
              showAiwaToast(context, l.flagThanks);
            },
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: AppTheme.sheetDecoration,
            padding: EdgeInsets.fromLTRB(
              22,
              18,
              22,
              36 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
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
                  EyebrowLabel(
                    l.flagEyebrow(providerName),
                    color: AppColors.rose700,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.flagTitle,
                    style: AppTextStyles.h3.copyWith(fontSize: 22, height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.flagBody,
                    style: AppTextStyles.micro.copyWith(
                      fontSize: AppTextStyles.fsLabelSmPlus,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final r in reasons) ...[
                    _ReasonRow(
                      label: r,
                      selected: reason == r,
                      onTap: () => setSheet(() => reason = r),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (reason == l.flagReasonOther) ...[
                    const SizedBox(height: 4),
                    AiwaTextField(
                      controller: note,
                      maxLines: 3,
                      placeholder: l.flagHelpUs,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.danger700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AiwaButton(
                          label: l.commonCancel,
                          variant: AiwaButtonVariant.secondary,
                          fullWidth: true,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AiwaButton(
                          label: l.flagSubmit,
                          variant: AiwaButtonVariant.danger,
                          fullWidth: true,
                          loading: sending,
                          onPressed: reason == null ? null : submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(note.dispose);
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.dur2,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum100 : AppColors.paper,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppColors.plum700 : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.plum900 : AppColors.ink,
                ),
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
