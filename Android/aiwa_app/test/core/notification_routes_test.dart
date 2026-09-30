import 'package:aiwa_app/core/router/app_router.dart';
import 'package:aiwa_app/features/notifications/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// FE-3: a tapped push and a tapped inbox row go to the same screen.
void main() {
  String? customer(String type, [String? id]) =>
      notificationTarget(type: type, bookingId: id, isProvider: false);
  String? provider(String type, [String? id]) =>
      notificationTarget(type: type, bookingId: id, isProvider: true);

  test('customer booking notifications open the live booking', () {
    expect(customer('BOOKING_ACCEPTED', '42'), '/booking/42/track');
    expect(
      customer('BOOKING_TIME_PROPOSED', '42'),
      '/booking/42/proposed-time',
    );
    expect(customer('CHAT_MESSAGE', '42'), '/booking/42/chat');
    expect(customer('BOOKING_REJECTED', '42'), '/booking/42/rejected');
    expect(customer('BOOKING_EXPIRED', '42'), '/booking/42/expired');
    expect(customer('SAFETY_ALERT', '42'), '/booking/42/track');
  });

  test('provider notifications open the job, wallet or verification', () {
    expect(provider('BOOKING_CREATED', '7'), AppRoutes.providerBooking('7'));
    expect(provider('SETTLEMENT_DUE'), AppRoutes.providerWallet);
    expect(provider('COMMISSION_PAUSED'), AppRoutes.providerWallet);
    expect(
      provider('PROVIDER_VERIFICATION_APPROVED'),
      AppRoutes.providerPending,
    );
    expect(provider('PROVIDER_INFO_REQUESTED'), AppRoutes.providerPending);
  });

  test('terms changes ask to re-accept for everyone', () {
    expect(customer('TERMS_UPDATED'), AppRoutes.termsReaccept);
    expect(provider('TERMS_UPDATED'), AppRoutes.termsReaccept);
  });

  test('a push without a booking id (FCM sends "") only marks read', () {
    expect(customer('BOOKING_ACCEPTED', ''), isNull);
    expect(customer('BOOKING_ACCEPTED'), isNull);
    expect(customer('PROMO'), isNull);
    expect(provider('SOMETHING_ELSE', '1'), isNull);
  });
}
