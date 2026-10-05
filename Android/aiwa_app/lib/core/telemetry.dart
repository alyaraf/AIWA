import 'dart:developer' as developer;

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

/// Diagnostic note for failures the app survives (e.g. push setup). Logs the failure's
/// type, never its message: exception text can carry config values, URLs or tokens.
/// Also kept as a Sentry breadcrumb when Sentry is on; `developer.log` is silent in release.
void logDiagnostic(String message, {Object? error}) {
  final detail = error == null ? message : '$message (${error.runtimeType})';
  developer.log(detail, name: 'aiwa');
  Sentry.addBreadcrumb(Breadcrumb(category: 'diagnostic', message: detail));
}
