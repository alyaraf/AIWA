// CR-17: a booking request that fails with a 401, no network or anything
// unexpected must reach the screen as a Failure, never as a throw.
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/features/bookings/data/datasources/booking_remote_datasource.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/data/repositories/booking_repository_impl.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/live_booking_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final _booking = BookingModel.fromJson({
  'id': 7,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'ACCEPTED',
  'totalPrice': 350,
});

/// Throws [fail] while it is set; anything the tests do not touch throws too.
class _Remote implements BookingRemoteDataSource {
  Object? fail;
  int detailCalls = 0;

  @override
  Future<BookingModel> getBookingDetail(String bookingId) async {
    detailCalls++;
    if (fail != null) throw fail!;
    return _booking;
  }

  @override
  Future<BookingModel> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) async {
    if (fail != null) throw fail!;
    return _booking;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _failures = <String, Object>{
  'a 401': const UnauthorizedException(),
  'no network': const NetworkException(),
  'an unexpected error': StateError('bad payload'),
};

void main() {
  for (final MapEntry(key: name, value: error) in _failures.entries) {
    testWidgets('tracking load with $name: error + retry, poll keeps running', (
      tester,
    ) async {
      final remote = _Remote()..fail = error;
      final c = LiveBookingCubit(BookingRepositoryImpl(remote), '7');

      await c.load();
      // Not the endless skeleton: the page shows ErrorState with a retry.
      expect(c.state.booking, isNull);
      expect(c.state.loadError, isNotNull);

      c.startPolling();
      await tester.pump(const Duration(seconds: 15));
      expect(remote.detailCalls, 2, reason: 'first tick ran');
      await tester.pump(const Duration(seconds: 15));
      expect(remote.detailCalls, 3, reason: 'the poll survived a failed tick');

      remote.fail = null;
      await tester.pump(const Duration(seconds: 15));
      expect(c.state.booking, isNotNull);
      expect(c.state.loadError, isNull);
      await c.close();
    });

    test('reschedule failing with $name leaves the buttons not busy', () async {
      final remote = _Remote()..fail = error;
      final c = LiveBookingCubit(
        BookingRepositoryImpl(remote),
        '7',
        initial: _booking,
      );
      expect(await c.reschedule('2026-05-20', '13:00'), isFalse);
      expect(c.state.busy, isFalse);
      expect(c.state.actionError, isNotNull);
      await c.close();
    });
  }
}
