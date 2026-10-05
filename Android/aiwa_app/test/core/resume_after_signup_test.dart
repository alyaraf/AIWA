// M-08: the booking a guest was heading to survives every intermediate permission step.
import 'package:aiwa_app/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppRoutes.resumeAfterSignUp = null);

  test('the location step (next = notifications) leaves the deferred booking in place', () {
    AppRoutes.resumeAfterSignUp = '/booking-type/12';
    expect(AppRoutes.consumeResumeFor(AppRoutes.permNotifications), isNull);
    expect(AppRoutes.resumeAfterSignUp, '/booking-type/12');
  });

  test('the final step (next = home) takes it exactly once', () {
    AppRoutes.resumeAfterSignUp = '/booking-type/12';
    expect(AppRoutes.consumeResumeFor(AppRoutes.home), '/booking-type/12');
    expect(AppRoutes.resumeAfterSignUp, isNull);
    expect(AppRoutes.consumeResumeFor(AppRoutes.home), isNull);
  });

  test('the whole sequence location -> notifications -> home resumes the booking', () {
    AppRoutes.resumeAfterSignUp = '/provider/7';
    final afterLocation = AppRoutes.consumeResumeFor(AppRoutes.permNotifications); // step 1: allow or deny
    final afterNotifications = AppRoutes.consumeResumeFor(AppRoutes.home); // step 2
    expect(afterLocation, isNull);
    expect(afterNotifications, '/provider/7');
  });
}
