import 'package:equatable/equatable.dart';
import '../../../bookings/domain/entities/booking_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final List<BookingEntity> bookings;
  final bool hasMore;
  final String? filterStatus;

  const DashboardLoaded({
    required this.stats,
    required this.bookings,
    required this.hasMore,
    this.filterStatus,
  });

  DashboardLoaded copyWith({
    DashboardStats? stats,
    List<BookingEntity>? bookings,
    bool? hasMore,
    String? filterStatus,
  }) =>
      DashboardLoaded(
        stats: stats ?? this.stats,
        bookings: bookings ?? this.bookings,
        hasMore: hasMore ?? this.hasMore,
        filterStatus: filterStatus ?? this.filterStatus,
      );

  @override
  List<Object?> get props => [stats, bookings, hasMore, filterStatus];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
