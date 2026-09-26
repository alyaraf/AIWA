import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remote;
  DashboardRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, DashboardStats>> getStats() async {
    try {
      final stats = await _remote.getStats();
      return Right(stats);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await _remote.getProviderBookings(
          status: status, page: page, size: size);
      return Right(PagedData(
        content: result.content,
        totalElements: result.totalElements,
        totalPages: result.totalPages,
        number: result.number,
        size: result.size,
        last: result.last,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> acceptBooking(
      String bookingId) async {
    try {
      return Right(await _remote.acceptBooking(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> rejectBooking(
      String bookingId, String reason) async {
    try {
      return Right(await _remote.rejectBooking(bookingId, reason));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> completeBooking(
      String bookingId) async {
    try {
      return Right(await _remote.completeBooking(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> markNoShow(
      String bookingId) async {
    try {
      return Right(await _remote.markNoShow(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> bookingOnTheWay(
      String bookingId) async {
    try {
      return Right(await _remote.onTheWay(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> bookingArrived(
      String bookingId) async {
    try {
      return Right(await _remote.arrived(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> bookingInProgress(
      String bookingId) async {
    try {
      return Right(await _remote.inProgress(bookingId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
