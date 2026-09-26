import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../bookings/domain/entities/booking_entity.dart';

class DashboardStats {
  final int totalBookings;
  final int pendingBookings;
  final int completedBookings;
  final double totalRevenue;
  final double averageRating;
  final int totalReviews;

  const DashboardStats({
    required this.totalBookings,
    required this.pendingBookings,
    required this.completedBookings,
    required this.totalRevenue,
    required this.averageRating,
    required this.totalReviews,
  });
}

abstract class DashboardRepository {
  Future<Either<Failure, DashboardStats>> getStats();

  Future<Either<Failure, PagedData<BookingEntity>>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
  });

  Future<Either<Failure, BookingEntity>> acceptBooking(String bookingId);

  Future<Either<Failure, BookingEntity>> rejectBooking(
      String bookingId, String reason);

  Future<Either<Failure, BookingEntity>> completeBooking(String bookingId);

  Future<Either<Failure, BookingEntity>> markNoShow(String bookingId);

  Future<Either<Failure, BookingEntity>> bookingOnTheWay(String bookingId);

  Future<Either<Failure, BookingEntity>> bookingArrived(String bookingId);

  Future<Either<Failure, BookingEntity>> bookingInProgress(String bookingId);
}
