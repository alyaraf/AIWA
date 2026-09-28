import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/aiwa_button.dart';
import '../../../../shared/widgets/eyebrow_label.dart';
import '../../domain/entities/booking_entity.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';

class BookingConfirmedPage extends StatelessWidget {
  final BookingEntity booking;

  const BookingConfirmedPage({super.key, required this.booking});

  DateTime? get _start {
    final t = booking.scheduledTime;
    return DateTime.tryParse(
      '${booking.scheduledDate} ${t.length == 5 ? '$t:00' : t}',
    );
  }

  // ponytail: Google Calendar template link (opens the Calendar app on
  // Android, the web elsewhere); add_2_calendar if iOS needs the native sheet.
  Future<void> _addToCalendar() async {
    final start = _start;
    if (start == null) return;
    final end = start.add(Duration(minutes: booking.serviceDurationMinutes));
    String f(DateTime d) => DateFormat("yyyyMMdd'T'HHmmss", 'en').format(d);
    await launchUrl(
      Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': '${booking.serviceName} · ${booking.displayProviderName}',
        'dates': '${f(start)}/${f(end)}',
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  /// 'Tuesday, May 19 at 12:30 PM' (screens.jsx:478).
  String _whenLong(AppLocalizations l) {
    final dt = _start;
    if (dt == null) {
      return l.formatWhen(booking.scheduledDate, booking.scheduledTime);
    }
    return l.bookingWhenLong(
      DateFormat.MMMMEEEEd(l.localeName).format(dt),
      DateFormat('h:mm a', l.localeName).format(dt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final insets = MediaQuery.paddingOf(context);
    final provider = booking.displayProviderName;
    // Headline uses the owner's first name, the Provider row the business.
    final firstName =
        (booking.providerName.isNotEmpty ? booking.providerName : provider)
            .split(' ')
            .first;
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
                LucideIcons.check,
                size: 48,
                color: AppColors.success700,
              ),
            ),
            const SizedBox(height: 20),
            EyebrowLabel(l.bookingPlaced, color: AppColors.rose700),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.h1.copyWith(
                    fontSize: 30,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                  children: spansOf(l.bookingSaidAiwa('{aiwa}', firstName), {
                    'aiwa': TextSpan(
                      text: l.bookingAiwaWord,
                      style: TextStyle(
                        color: AppColors.rose700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  }),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                l.bookingConfirmPing(_whenLong(l)),
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.ink2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _Row(label: l.bookingProvider, value: provider),
                  const _Divider(),
                  _Row(label: l.bookingService, value: booking.serviceName),
                  const _Divider(),
                  _Row(
                    label: l.bookingWhen,
                    value: l.formatWhen(
                      booking.scheduledDate,
                      booking.scheduledTime,
                    ),
                  ),
                  const _Divider(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(l.bookingTotal, style: AppTextStyles.meta),
                      ),
                      Text(
                        l.egp(booking.servicePrice),
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 20,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AiwaButton(
              label: l.bookingViewMine,
              // prototype.jsx:693 — the label says bookings, the target is
              // Tracking.
              onPressed: () =>
                  context.go('/booking/${booking.id}/track', extra: booking),
              fullWidth: true,
              size: AiwaButtonSize.lg,
            ),
            const SizedBox(height: 10),
            AiwaButton(
              label: l.bookingAddToCalendar,
              onPressed: _addToCalendar,
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
