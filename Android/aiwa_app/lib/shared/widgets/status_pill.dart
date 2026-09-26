import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Booking status pill with a coloured dot — `StatusPill` in the kit.
/// Accepts backend statuses (`ON_THE_WAY`) and kit ids (`onway`).
class StatusPill extends StatelessWidget {
  final String status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.dot),
          ),
          const SizedBox(width: 6),
          Text(
            c.label,
            style: AppTextStyles.labelSm.copyWith(color: c.fg, height: 1.2),
          ),
        ],
      ),
    );
  }

  static _StatusConfig _config(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _StatusConfig(
          AppColors.warn100,
          AppColors.warn700,
          AppColors.warn500,
          'Pending',
        );
      case 'accepted':
      case 'confirmed':
        return _StatusConfig(
          AppColors.info100,
          AppColors.info700,
          AppColors.info500,
          'Confirmed',
        );
      case 'on_the_way':
      case 'onway':
        return _StatusConfig(
          AppColors.plum100,
          AppColors.plum700,
          AppColors.plum500,
          'On the way',
        );
      case 'arrived':
        return _StatusConfig(
          AppColors.plum100,
          AppColors.plum900,
          AppColors.plum700,
          'Arrived',
        );
      case 'in_progress':
      case 'progress':
        return _StatusConfig(
          AppColors.rose100,
          AppColors.rose700,
          AppColors.rose500,
          'In progress',
        );
      case 'completed':
        return _StatusConfig(
          AppColors.success100,
          AppColors.success700,
          AppColors.success500,
          'Completed',
        );
      case 'cancelled':
        return _StatusConfig(
          AppColors.danger100,
          AppColors.danger700,
          AppColors.danger500,
          'Cancelled',
        );
      case 'rejected':
        return _StatusConfig(
          AppColors.danger100,
          AppColors.danger700,
          AppColors.danger500,
          'Rejected',
        );
      case 'no_show':
      case 'noshow':
        return _StatusConfig(
          AppColors.warn100,
          AppColors.warn700,
          AppColors.warn500,
          'No-show',
        );
      case 'expired':
        return _StatusConfig(
          AppColors.cream,
          AppColors.ink3,
          AppColors.ink4,
          'Expired',
        );
      case 'disputed':
        return _StatusConfig(
          AppColors.danger100,
          AppColors.danger700,
          AppColors.danger500,
          'Disputed',
        );
      default:
        return _StatusConfig(
          AppColors.cream,
          AppColors.ink3,
          AppColors.ink4,
          status,
        );
    }
  }
}

class _StatusConfig {
  final Color bg, fg, dot;
  final String label;
  _StatusConfig(this.bg, this.fg, this.dot, this.label);
}
