import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_entity.dart';

abstract class BookingState extends Equatable {
  const BookingState();
  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class BookingCreated extends BookingState {
  final BookingEntity booking;
  const BookingCreated(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingListLoaded extends BookingState {
  final List<BookingEntity> bookings;
  final bool hasMore;
  final String? filterStatus;

  const BookingListLoaded({
    required this.bookings,
    required this.hasMore,
    this.filterStatus,
  });

  BookingListLoaded copyWith({
    List<BookingEntity>? bookings,
    bool? hasMore,
    String? filterStatus,
  }) =>
      BookingListLoaded(
        bookings: bookings ?? this.bookings,
        hasMore: hasMore ?? this.hasMore,
        filterStatus: filterStatus ?? this.filterStatus,
      );

  @override
  List<Object?> get props => [bookings, hasMore, filterStatus];
}

class BookingCancelled extends BookingState {
  final BookingEntity booking;
  const BookingCancelled(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingRescheduled extends BookingState {
  final BookingEntity booking;
  const BookingRescheduled(this.booking);
  @override
  List<Object?> get props => [booking];
}

class BookingError extends BookingState {
  final String message;
  const BookingError(this.message);
  @override
  List<Object?> get props => [message];
}
