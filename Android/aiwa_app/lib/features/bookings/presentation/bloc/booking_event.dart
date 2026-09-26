import 'package:equatable/equatable.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class BookingCreateEvent extends BookingEvent {
  final String providerId;
  final String serviceId;
  final String scheduledDate;
  final String scheduledTime;
  final String? customerNote;

  const BookingCreateEvent({
    required this.providerId,
    required this.serviceId,
    required this.scheduledDate,
    required this.scheduledTime,
    this.customerNote,
  });

  @override
  List<Object?> get props =>
      [providerId, serviceId, scheduledDate, scheduledTime];
}

class BookingLoadMyEvent extends BookingEvent {
  final String? status;
  const BookingLoadMyEvent({this.status});
  @override
  List<Object?> get props => [status];
}

class BookingLoadMoreEvent extends BookingEvent {}

class BookingCancelEvent extends BookingEvent {
  final String bookingId;
  const BookingCancelEvent(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

class BookingRescheduleEvent extends BookingEvent {
  final String bookingId;
  final String newDate;
  final String newTime;

  const BookingRescheduleEvent({
    required this.bookingId,
    required this.newDate,
    required this.newTime,
  });

  @override
  List<Object?> get props => [bookingId, newDate, newTime];
}
