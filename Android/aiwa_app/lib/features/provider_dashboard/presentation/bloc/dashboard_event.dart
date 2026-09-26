import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class DashboardLoadEvent extends DashboardEvent {}

class DashboardFilterStatusEvent extends DashboardEvent {
  final String? status;
  const DashboardFilterStatusEvent(this.status);
  @override
  List<Object?> get props => [status];
}

class DashboardAcceptBookingEvent extends DashboardEvent {
  final String bookingId;
  const DashboardAcceptBookingEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class DashboardRejectBookingEvent extends DashboardEvent {
  final String bookingId;
  final String reason;
  const DashboardRejectBookingEvent(this.bookingId, this.reason);
  @override
  List<Object?> get props => [bookingId, reason];
}

class DashboardCompleteBookingEvent extends DashboardEvent {
  final String bookingId;
  const DashboardCompleteBookingEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class DashboardNoShowEvent extends DashboardEvent {
  final String bookingId;
  const DashboardNoShowEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class DashboardOnTheWayEvent extends DashboardEvent {
  final String bookingId;
  const DashboardOnTheWayEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class DashboardArrivedEvent extends DashboardEvent {
  final String bookingId;
  const DashboardArrivedEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class DashboardInProgressEvent extends DashboardEvent {
  final String bookingId;
  const DashboardInProgressEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}
