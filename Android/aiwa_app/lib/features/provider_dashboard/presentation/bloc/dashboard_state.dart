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
  final List<BookingEntity> pending;

  const DashboardLoaded({required this.stats, required this.pending});

  @override
  List<Object?> get props => [stats, pending];
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
