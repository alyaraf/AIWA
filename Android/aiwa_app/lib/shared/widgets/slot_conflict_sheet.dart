import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'aiwa_button.dart';
import 'aiwa_sheet.dart';
import 'package:aiwa_app/l10n/l10n.dart';

/// SlotConflictSheet (system-screens.jsx:150-186). Pops the picked entry of
/// [alternatives], or null for 'Pick another day' / dismiss.
Future<String?> showSlotConflictSheet(
  BuildContext context, {
  required String providerName,
  required List<String> alternatives,
  String Function(String)? labelOf,
}) => showAiwaSheet<String>(
  context,
  builder: (ctx) {
    final label = labelOf ?? (String t) => t;
    String? picked;
    return StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetWarnHead(
            icon: Icons.event_busy_outlined,
            eyebrow: AppLocalizations.of(ctx).slotJustTaken,
            title: AppLocalizations.of(ctx).slotTitle,
            body: AppLocalizations.of(ctx).slotBody(providerName),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in alternatives)
                GestureDetector(
                  onTap: () => setState(() => picked = a),
                  child: AnimatedContainer(
                    duration: AppTheme.dur2,
                    curve: AppTheme.easeSoft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: picked == a ? AppColors.plum700 : AppColors.paper,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        width: 1.5,
                        color: picked == a
                            ? Colors.transparent
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      label(a),
                      style: AppTextStyles.label.copyWith(
                        fontSize: 14,
                        color: picked == a ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: AiwaButton(
                  label: AppLocalizations.of(ctx).slotPickAnotherDay,
                  variant: AiwaButtonVariant.secondary,
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AiwaButton(
                  label: picked == null
                      ? AppLocalizations.of(ctx).slotBook
                      : AppLocalizations.of(ctx).slotBookTime(label(picked!)),
                  size: AiwaButtonSize.lg,
                  fullWidth: true,
                  onPressed: picked == null
                      ? null
                      : () => Navigator.of(ctx).pop(picked),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  },
);
