// CR-15: SOS never sticks on "Alerting…" and can be raised again after
// "I'm safe".
import 'package:aiwa_app/core/di/injection_container.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/features/bookings/data/datasources/booking_remote_datasource.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/data/repositories/booking_repository_impl.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/live_booking_cubit.dart';
import 'package:aiwa_app/features/bookings/presentation/pages/tracking_page.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../test_helpers.dart';

/// A home visit with the provider on the way: the SOS card is on screen.
final _booking = BookingModel.fromJson({
  'id': 7,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'ON_THE_WAY',
  'homeService': true,
  'totalPrice': 350,
});

/// sendSos / sosReport throw [fail] while it is set.
class _Remote implements BookingRemoteDataSource {
  Object? fail;
  int sosCalls = 0;
  // No SOS is open until one is raised (load() now shows an open one: CR-16).
  bool open = false;

  @override
  Future<BookingModel> getBookingDetail(String bookingId) async => _booking;

  @override
  Future<void> sendSos(
    String bookingId, {
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? locationTime,
    double? locationAccuracy,
  }) async {
    sosCalls++;
    if (fail != null) throw fail!;
    open = true;
  }

  @override
  Future<SosReport?> sosReport(String bookingId) async {
    if (fail != null) throw fail!;
    if (!open) return null;
    return const SosReport(supportAlerted: true, contactsTexted: 1);
  }

  @override
  Future<void> resolveSos(String bookingId) async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _failures = <String, Object>{
  'a 401': const UnauthorizedException(),
  'no network': const NetworkException(),
  'an unexpected error': StateError('bad payload'),
};

void main() {
  setUpAll(() {
    useTestFonts();
    return initializeDateFormatting('en');
  });

  test('sos() failing with a 401, no network or an unexpected error never '
      'stays on alerting and can be retried', () async {
    for (final MapEntry(key: name, value: error) in _failures.entries) {
      final remote = _Remote()..fail = error;
      final c = LiveBookingCubit(
        BookingRepositoryImpl(remote),
        '7',
        initial: _booking,
        locate: () async => null,
      );
      await c.sos();
      expect(c.state.sos, SosStage.none, reason: name);

      remote.fail = null;
      await c.sos();
      expect(c.state.sos, SosStage.notified, reason: '$name, retried');
      await c.close();
    }
  });

  test('sos() leaves alerting even when locating throws', () async {
    final c = LiveBookingCubit(
      BookingRepositoryImpl(_Remote()),
      '7',
      initial: _booking,
      locate: () => throw StateError('no location service'),
    );
    await c.sos();
    expect(c.state.sos, SosStage.none);
    await c.close();
  });

  group('Tracking page', () {
    late _Remote remote;
    final l = lookupAppLocalizations(const Locale('en'));

    Future<void> open(WidgetTester tester) async {
      remote = _Remote();
      // No location permission: the SOS goes out without a fix.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (_) async => 0,
      );
      sl.registerSingleton<BookingRepository>(BookingRepositoryImpl(remote));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackingPage(bookingId: '7', booking: _booking),
        ),
      );
      await tester.pump();
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump();
      await tester.pump();
    }

    /// Disposes the page so its poll timers stop.
    Future<void> shut(WidgetTester tester) =>
        tester.pumpWidget(const SizedBox());

    tearDown(sl.reset);

    testWidgets('a failed SOS shows a retry and the 122 hint', (tester) async {
      await open(tester);
      remote.fail = const UnauthorizedException();
      await tap(tester, find.text(l.trackSos));
      expect(find.text(l.trackSosAlerting), findsNothing);
      expect(find.textContaining('122'), findsOneWidget);

      remote.fail = null;
      await tap(tester, find.text(l.commonRetry));
      expect(remote.sosCalls, 2);
      expect(find.text(l.trackImSafe), findsOneWidget);
      await shut(tester);
    });

    testWidgets("after I'm safe, SOS can be raised again", (tester) async {
      await open(tester);
      await tap(tester, find.text(l.trackSos));
      await tap(tester, find.text(l.trackImSafe));
      expect(find.text(l.trackSosLogged), findsOneWidget);

      await tap(tester, find.text(l.trackSos));
      expect(remote.sosCalls, 2);
      expect(find.text(l.trackImSafe), findsOneWidget);
      await shut(tester);
    });
  });
}
