import 'package:sentry_flutter/sentry_flutter.dart';

/// Booking funnel step: `search`, `book`, `accept`, `complete`.
/// Ids only — never phone numbers, emails, names or search text.
/// A no-op when Sentry wasn't initialised (no SENTRY_DSN).
void trackFunnel(String step, {Object? bookingId}) => Sentry.addBreadcrumb(
  Breadcrumb(
    category: 'funnel',
    message: step,
    data: {if (bookingId != null) 'bookingId': '$bookingId'},
  ),
);
