import 'package:equatable/equatable.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class BookingCreateEvent extends BookingEvent {
  final String providerId;
  final String serviceId;
  final String? scheduledDate;
  final String? scheduledTime;
  final String? staffId;
  final bool bookNow;
  final bool homeService;
  final String? savedAddressId;
  final String? customerNote;

  const BookingCreateEvent({
    required this.providerId,
    required this.serviceId,
    this.scheduledDate,
    this.scheduledTime,
    this.staffId,
    this.bookNow = false,
    this.homeService = false,
    this.savedAddressId,
    this.customerNote,
  });

  @override
  List<Object?> get props => [
    providerId,
    serviceId,
    scheduledDate,
    scheduledTime,
    staffId,
    bookNow,
    homeService,
    savedAddressId,
    customerNote,
  ];
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
