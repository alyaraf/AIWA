// M-09: a notification shown locally and tapped after the app was killed reaches the same validated route pipeline
// as an FCM launch message.
import 'dart:convert';

import 'package:aiwa_app/core/push/push_service.dart';
import 'package:aiwa_app/features/notifications/notification_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the payload written for a foreground notification decodes to push data', () {
    final payload = jsonEncode({'type': 'BOOKING_ACCEPTED', 'relatedBookingId': 42});
    final tap = PushService.tapFromPayload(payload)!;
    expect(tap, {'type': 'BOOKING_ACCEPTED', 'relatedBookingId': '42'});
  });

  test('missing, empty, malformed and non-object payloads are ignored', () {
    expect(PushService.tapFromPayload(null), isNull);
    expect(PushService.tapFromPayload(''), isNull);
    expect(PushService.tapFromPayload('not json'), isNull);
    expect(PushService.tapFromPayload('[1,2]'), isNull);
    expect(PushService.tapFromPayload('"str"'), isNull);
  });

  test('a launch payload is routed by the same rules as a push tap (positive ids only)', () {
    final good = PushService.tapFromPayload(jsonEncode({'type': 'BOOKING_ACCEPTED', 'relatedBookingId': '42'}))!;
    expect(
      notificationTarget(type: good['type']!, bookingId: good['relatedBookingId'], isProvider: false),
      '/booking/42/track',
    );
    final hostile = PushService.tapFromPayload(jsonEncode({'type': 'BOOKING_ACCEPTED', 'relatedBookingId': '../../admin'}))!;
    expect(
      notificationTarget(type: hostile['type']!, bookingId: hostile['relatedBookingId'], isProvider: false),
      isNull,
    );
  });
}
