import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remote;
  BookingRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, BookingEntity>> createBooking({
    required String providerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    String? customerNote,
  }) async {
    try {
      final result = await _remote.createBooking(
        providerId: providerId,
        serviceId: serviceId,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        customerNote: customerNote,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result =
          await _remote.getMyBookings(status: status, page: page, size: size);
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
  Future<Either<Failure, BookingEntity>> getBookingDetail(
      String bookingId) async {
    try {
      final result = await _remote.getBookingDetail(bookingId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking(
      String bookingId) async {
    try {
      final result = await _remote.cancelBooking(bookingId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, BookingEntity>> rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) async {
    try {
      final result = await _remote.rescheduleBooking(
        bookingId: bookingId,
        newDate: newDate,
        newTime: newTime,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
