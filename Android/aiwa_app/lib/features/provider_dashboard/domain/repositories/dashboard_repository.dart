import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../../../bookings/domain/entities/booking_entity.dart';

/// GET /bookings/provider ignores `status` and sorts oldest first, so lists
/// fetch one big page and filter client-side.
// ponytail: newest bookings drop off past 100; add the backend status filter
// (PROV-08-F1) and page properly when a provider outgrows it.
const providerBookingsPageSize = 100;

/// Bumped after any provider booking action so Today, Bookings and the tab
/// badge (kept alive by the tab shell) reload.
// ponytail: global signal; swap for a shared cubit if more screens need it.
final providerBookingsChanged = ValueNotifier<int>(0);

/// Backend DashboardDto (GET /provider/dashboard).
class DashboardStats {
  final int totalBookings;
  final int pendingBookings;
  final int confirmedBookings;
  final int completedBookings;
  final double totalRevenue;
  final double averageRating;
  final int totalReviews;
  final int totalClients;
  final List<BookingEntity> todayBookings;

  const DashboardStats({
    required this.totalBookings,
    required this.pendingBookings,
    required this.confirmedBookings,
    required this.completedBookings,
    required this.totalRevenue,
    required this.averageRating,
    this.totalReviews = 0,
    required this.totalClients,
    this.todayBookings = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> d) => DashboardStats(
    totalBookings: (d['totalBookings'] as num?)?.toInt() ?? 0,
    pendingBookings: (d['pendingBookings'] as num?)?.toInt() ?? 0,
    confirmedBookings: (d['confirmedBookings'] as num?)?.toInt() ?? 0,
    completedBookings: (d['completedBookings'] as num?)?.toInt() ?? 0,
    totalRevenue: (d['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
    totalReviews: (d['totalReviews'] as num?)?.toInt() ?? 0,
    totalClients: (d['totalClients'] as num?)?.toInt() ?? 0,
    todayBookings: (d['todayBookings'] as List<dynamic>? ?? const [])
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

abstract class DashboardRepository {
  Future<Either<Failure, DashboardStats>> getStats();

  Future<Either<Failure, PagedData<BookingEntity>>> getProviderBookings({
    String? status,
    int page = 0,
    int size = 20,
    bool newestFirst = false,
  });

  Future<Either<Failure, BookingEntity>> acceptBooking(String bookingId);

  Future<Either<Failure, BookingEntity>> rejectBooking(
    String bookingId,
    String reason,
  );

  /// cashCollected=false marks the booking DISPUTED.
  Future<Either<Failure, BookingEntity>> completeBooking(
    String bookingId, {
    bool cashCollected = true,
    String? note,
  });

  Future<Either<Failure, BookingEntity>> bookingOnTheWay(String bookingId);

  Future<Either<Failure, BookingEntity>> bookingArrived(String bookingId);

  Future<Either<Failure, BookingEntity>> bookingInProgress(String bookingId);

  /// PATCH /bookings/{id}/propose-time; [date] `yyyy-MM-dd`, [time] `HH:mm`.
  Future<Either<Failure, BookingEntity>> proposeTime(
    String bookingId,
    String date,
    String time,
  );

  /// Not in the backend yet.
  Future<Either<Failure, BookingEntity>> quoteTravelFee(
    String bookingId,
    double amount,
  );
}
