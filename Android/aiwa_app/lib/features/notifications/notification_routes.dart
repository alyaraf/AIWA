import '../../core/router/app_router.dart';

/// Where tapping a notification goes, for both the inbox and a push (FE-3).
/// [bookingId] is the notification's related booking. Null means "no screen":
/// the tap only marks it read.
String? notificationTarget({
  required String type,
  required String? bookingId,
  required bool isProvider,
}) {
  final t = type.toUpperCase();
  final id = (bookingId == null || bookingId.isEmpty) ? null : bookingId;
  if (t.contains('TERMS')) return AppRoutes.termsReaccept;

  if (isProvider) {
    // FE-25: bookings open the job, money goes to the wallet, verification to
    // the pending screen.
    if (t.startsWith('COMMISSION_') || t.startsWith('SETTLEMENT_')) {
      return AppRoutes.providerWallet;
    }
    if (t.startsWith('PROVIDER_VERIFICATION_') ||
        t == 'PROVIDER_INFO_REQUESTED') {
      return AppRoutes.providerPending;
    }
    if (id != null &&
        RegExp(r'^(BOOKING|CHAT|PAYMENT|TRAVEL_FEE)_').hasMatch(t)) {
      return AppRoutes.providerBooking(id);
    }
    return null;
  }

  // Customers: booking notifications open the live booking.
  if (id != null && RegExp(r'^(BOOKING|CHAT|PAYMENT|SAFETY)_').hasMatch(t)) {
    return switch (t) {
      'BOOKING_TIME_PROPOSED' => '/booking/$id/proposed-time',
      'CHAT_MESSAGE' => '/booking/$id/chat',
      'BOOKING_REJECTED' => '/booking/$id/rejected',
      'BOOKING_EXPIRED' => '/booking/$id/expired',
      _ => '/booking/$id/track',
    };
  }
  return null;
}
