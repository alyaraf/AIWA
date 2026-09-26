import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../domain/entities/booking_entity.dart';

class BookingConfirmedPage extends StatelessWidget {
  final BookingEntity booking;

  const BookingConfirmedPage({super.key, required this.booking});

  String get _when {
    try {
      final d = DateTime.parse(booking.scheduledDate);
      final t = booking.scheduledTime.length >= 5
          ? booking.scheduledTime.substring(0, 5)
          : booking.scheduledTime;
      return '${DateFormat('EEE, MMM d').format(d)} · $t';
    } catch (_) {
      return '${booking.scheduledDate} · ${booking.scheduledTime}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final provider = booking.displayProviderName;
    return Scaffold(
      backgroundColor: AppColors.bone,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          insets.top + 70,
          28,
          insets.bottom + 28,
        ),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.success100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 48,
                color: AppColors.success700,
              ),
            ),
            const SizedBox(height: 20),
            EyebrowLabel('Booking placed', color: AppColors.rose700),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.h1.copyWith(fontSize: 30, height: 1.1),
                  children: [
                    const TextSpan(text: 'You said '),
                    TextSpan(
                      text: 'aiwa',
                      style: TextStyle(
                        color: AppColors.rose700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(text: '. We told $provider.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                "$_when. We'll ping you the moment they confirm — usually within 30 minutes.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _Row(label: 'Provider', value: provider),
                  const _Divider(),
                  _Row(label: 'Service', value: booking.serviceName),
                  const _Divider(),
                  _Row(label: 'When', value: _when),
                  const _Divider(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text('Total', style: AppTextStyles.meta)),
                      Text(
                        'EGP ${NumberFormat.decimalPattern('en').format(booking.servicePrice.round())}',
                        style: AppTextStyles.h3.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AiwaButton(
              label: 'View my bookings',
              onPressed: () => context.go(AppRoutes.myBookings),
              fullWidth: true,
              size: AiwaButtonSize.lg,
            ),
            const SizedBox(height: 10),
            AiwaButton(
              label: 'Back to home',
              onPressed: () => context.go(AppRoutes.home),
              variant: AiwaButtonVariant.ghost,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.meta),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.divider,
    );
  }
}
