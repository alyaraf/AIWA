import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/telemetry.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remote;
  DashboardRepositoryImpl(this._remote);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, DashboardStats>> getStats() =>
      _guard(_remote.getStats);

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) => _guard(
    () => _remote.getProviderBookings(status: status, page: page, size: size),
  );

  @override
  // ponytail: funnel steps live here, not in a bloc — the provider pages
  // call this repository directly and every accept/complete goes through it.
  Future<Either<Failure, BookingEntity>> acceptBooking(String bookingId) =>
      _guard(() async {
        final b = await _remote.acceptBooking(bookingId);
        trackFunnel('accept', bookingId: bookingId);
        return b;
      });

  @override
  Future<Either<Failure, BookingEntity>> rejectBooking(
    String bookingId,
    String reason,
  ) => _guard(() => _remote.rejectBooking(bookingId, reason));

  @override
  Future<Either<Failure, BookingEntity>> completeBooking(
    String bookingId, {
    bool cashCollected = true,
  }) => _guard(() async {
    final b = await _remote.completeBooking(
      bookingId,
      cashCollected: cashCollected,
    );
    trackFunnel('complete', bookingId: bookingId);
    return b;
  });

  @override
  Future<Either<Failure, BookingEntity>> bookingOnTheWay(String bookingId) =>
      _guard(() => _remote.onTheWay(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> bookingArrived(String bookingId) =>
      _guard(() => _remote.arrived(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> bookingInProgress(String bookingId) =>
      _guard(() => _remote.inProgress(bookingId));

  @override
  Future<Either<Failure, BookingEntity>> proposeTime(
    String bookingId,
    String date,
    String time,
  ) => _guard(() => _remote.proposeTime(bookingId, date, time));

  // BACKEND GAP: no per-booking travel-fee quote endpoint (only the flat
  // PATCH /provider/mode/travel-fee).
  @override
  Future<Either<Failure, BookingEntity>> quoteTravelFee(
    String bookingId,
    double amount,
  ) async => const Left(NotSupportedFailure('Quoting a travel fee'));
}
