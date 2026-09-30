import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/live_booking_cubit.dart';
import 'package:aiwa_app/features/bookings/presentation/pages/booking_action_pages.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:aiwa_app/l10n/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;

final _json = {
  'id': 7,
  'provider': {'id': 12, 'businessName': 'Nadia Studio', 'latitude': 30.0},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'COMPLETED',
  'homeService': true,
  'totalPrice': 470,
  'travelFee': 120,
  'paymentStatus': 'CASH_PENDING',
  'proposedDate': '2026-05-21',
  'proposedStartTime': '16:00:00',
  'cancelledAt': '2026-05-18T19:42:00',
  'rejectionReason': 'Fully booked',
};

/// Only what the cubit touches; anything else throws.
class _Repo implements BookingRepository {
  final BookingEntity booking;
  _Repo(this.booking);
  String? cancelledWith;

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking(
    String id, {
    String? reason,
  }) async {
    cancelledWith = reason;
    return Right(booking);
  }

  /// What sendSos returns, and whether GET /safety then shows an open SOS.
  Either<Failure, void> sosResult = const Right(null);
  bool recorded = false;
  ({double? lat, double? lng})? sentAt;

  @override
  Future<Either<Failure, void>> sendSos(
    String id, {
    double? latitude,
    double? longitude,
  }) async {
    sentAt = (lat: latitude, lng: longitude);
    return sosResult;
  }

  @override
  Future<Either<Failure, bool>> hasOpenSos(String id) async => Right(recorded);

  @override
  Future<Either<Failure, void>> resolveSos(String id) async =>
      const Left(NotSupportedFailure('Closing an SOS'));

  @override
  Future<Either<Failure, BookingEntity>> confirmPayment(
    String id, {
    required bool paid,
    String? providerId,
    String? reason,
  }) async => const Left(ServerFailure('nope'));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  test('BookingDto live fields and labels', () {
    final b = BookingModel.fromJson(_json);
    expect(b.homeService, isTrue);
    expect(b.travelFee, 120);
    expect(b.basePrice, 350);
    expect(b.paymentSettled, isFalse);
    expect(b.hasProposal, isTrue);
    expect(b.rejectionReason, 'Fully booked');
    expect(b.cancelledAt, DateTime(2026, 5, 18, 19, 42));
    expect(b.providerLat, 30.0);
    final l = lookupAppLocalizations(const Locale('en'));
    expect(
      l.formatWhen(b.scheduledDate, b.scheduledTime),
      'Tue, May 19 · 12:30 PM',
    );
    expect(
      l.formatWhen(b.proposedDate!, b.proposedStartTime!),
      'Thu, May 21 · 4:00 PM',
    );
    expect(l.egp(1250), 'EGP 1,250');
    expect(mmss(30 * 60), '30:00');
    expect(mmss(119), '01:59');
  });

  test('LiveBookingCubit: SOS stages, cancel reason, inline failure', () async {
    final b = BookingModel.fromJson(_json);
    final repo = _Repo(b);
    final c = LiveBookingCubit(repo, '7', initial: b);

    await c.sos();
    expect(c.state.sos, SosStage.notified);
    await c.imSafe(); // stub fails; the incident is still logged
    expect(c.state.sos, SosStage.logged);

    expect(await c.cancel('Changed my mind'), isTrue);
    expect(repo.cancelledWith, 'Changed my mind');

    expect(await c.confirmPayment(paid: true), isFalse);
    expect(c.state.actionError, 'nope');
    expect(c.state.busy, isFalse);
    await c.close();
  });

  test('SOS carries the location when there is a fix (FE-31)', () async {
    final b = BookingModel.fromJson(_json);
    final repo = _Repo(b);
    final c = LiveBookingCubit(
      repo,
      '7',
      initial: b,
      locate: () async => (lat: 30.05, lng: 31.23),
    );
    await c.sos();
    expect(repo.sentAt, (lat: 30.05, lng: 31.23));
    expect(c.state.sos, SosStage.notified);
    await c.close();
  });

  test('SOS without a fix is still sent', () async {
    final b = BookingModel.fromJson(_json);
    final repo = _Repo(b);
    final c = LiveBookingCubit(repo, '7', initial: b, locate: () async => null);
    await c.sos();
    expect(repo.sentAt, (lat: null, lng: null));
    expect(c.state.sos, SosStage.notified);
    await c.close();
  });

  test('a timed-out SOS that was recorded shows as sent, not failed', () async {
    final b = BookingModel.fromJson(_json);
    final repo = _Repo(b)
      ..sosResult = const Left(NetworkFailure('Connection timed out'))
      ..recorded = true;
    final c = LiveBookingCubit(repo, '7', initial: b, locate: () async => null);
    await c.sos();
    expect(c.state.sos, SosStage.notified);
    expect(c.state.actionError, isNull);
    await c.close();
  });

  test('an SOS that really failed says so', () async {
    final b = BookingModel.fromJson(_json);
    final repo = _Repo(b)
      ..sosResult = const Left(NetworkFailure('Connection timed out'));
    final c = LiveBookingCubit(repo, '7', initial: b, locate: () async => null);
    await c.sos();
    expect(c.state.sos, SosStage.none);
    expect(c.state.actionError, 'Connection timed out');
    await c.close();
  });
}
