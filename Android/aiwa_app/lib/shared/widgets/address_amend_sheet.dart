import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../features/bookings/domain/entities/saved_address_entity.dart';
import 'aiwa_button.dart';
import 'aiwa_sheet.dart';

/// Picks another saved address for a home visit (the destination amendment, B-05). Pops the chosen address id, or null
/// when dismissed. [needsReconfirm] is true for an accepted visit: the sheet says up front that the provider has to
/// confirm again, so the customer is not surprised by the booking returning to Pending.
Future<String?> showAddressAmendSheet(
  BuildContext context, {
  required String providerName,
  required List<SavedAddressEntity> addresses,
  required String? currentAddress,
  required bool needsReconfirm,
}) => showAiwaSheet<String>(
  context,
  builder: (ctx) {
    final l = AppLocalizations.of(ctx);
    // The address the visit already goes to cannot be "changed" to.
    final choices = [
      for (final a in addresses)
        if (a.addressLine != currentAddress) a,
    ];
    String? picked;
    return StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetWarnHead(
            icon: LucideIcons.mapPin,
            eyebrow: l.addressAmendEyebrow,
            title: l.addressAmendTitle,
            body: needsReconfirm
                ? l.addressAmendReconfirm(providerName)
                : l.addressAmendBody(providerName),
          ),
          if (currentAddress != null && currentAddress.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.addressAmendCurrent(currentAddress),
              style: AppTextStyles.micro.copyWith(fontSize: AppTextStyles.fsMicroPlus),
            ),
          ],
          const SizedBox(height: 14),
          if (choices.isEmpty)
            Text(
              l.addressAmendNone,
              key: const Key('address-amend-none'),
              style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
            )
          else
            for (final a in choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  selected: picked == a.id,
                  child: GestureDetector(
                    key: Key('address-choice-${a.id}'),
                    onTap: () => setState(() => picked = a.id),
                    child: AnimatedContainer(
                      duration: AppTheme.dur2,
                      curve: AppTheme.easeSoft,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: picked == a.id ? AppColors.plum100 : Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                        border: Border.all(
                          width: 1.5,
                          color: picked == a.id ? AppColors.plum700 : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 16, color: AppColors.plum700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.addressLabel(a.label),
                                  style: AppTextStyles.label.copyWith(
                                    fontSize: AppTextStyles.fsMetaPlus,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Text(
                                  a.addressLine,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.micro.copyWith(
                                    fontSize: AppTextStyles.fsMicroPlus,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (picked == a.id)
                            Icon(LucideIcons.check, size: 16, color: AppColors.plum700),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 14),
          AiwaButton(
            label: l.addressAmendConfirm,
            size: AiwaButtonSize.lg,
            fullWidth: true,
            onPressed: picked == null ? null : () => Navigator.of(ctx).pop(picked),
          ),
        ],
      ),
    );
  },
);
