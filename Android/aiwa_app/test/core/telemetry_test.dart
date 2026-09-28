import 'package:aiwa_app/core/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('funnel breadcrumbs carry the step and booking id only', () async {
    final crumbs = <Breadcrumb>[];
    await Sentry.init((o) {
      o.dsn = 'https://key@o0.ingest.sentry.io/0'; // never sent: no events
      o.beforeBreadcrumb = (b, _) {
        if (b?.category == 'funnel') crumbs.add(b!);
        return b;
      };
    });
    addTearDown(Sentry.close);

    trackFunnel('search');
    trackFunnel('book', bookingId: 42);

    expect(crumbs.map((b) => b.message), ['search', 'book']);
    expect(crumbs.first.data, isEmpty);
    expect(crumbs.last.data, {'bookingId': '42'});
  });
}
