import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/cancel_booking_usecase.dart';
import '../../domain/usecases/create_booking_usecase.dart';
import '../../domain/usecases/get_available_slots_usecase.dart';
import '../../domain/usecases/get_my_bookings_usecase.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final CreateBookingUseCase createBooking;
  final GetMyBookingsUseCase getMyBookings;
  final GetAvailableSlotsUseCase getAvailableSlots;
  final CancelBookingUseCase cancelBooking;

  int _page = 0;
  String? _filterStatus;

  BookingBloc({
    required this.createBooking,
    required this.getMyBookings,
    required this.getAvailableSlots,
    required this.cancelBooking,
  }) : super(BookingInitial()) {
    on<BookingCreateEvent>(_onCreate);
    on<BookingLoadMyEvent>(_onLoadMy);
    on<BookingLoadMoreEvent>(_onLoadMore);
    on<BookingCancelEvent>(_onCancel);
    on<BookingRescheduleEvent>(_onReschedule);
  }

  Future<void> _onCreate(
      BookingCreateEvent event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    final result = await createBooking(
      providerId: event.providerId,
      serviceId: event.serviceId,
      scheduledDate: event.scheduledDate,
      scheduledTime: event.scheduledTime,
      customerNote: event.customerNote,
    );
    result.fold(
      (f) => emit(BookingError(f.message)),
      (booking) => emit(BookingCreated(booking)),
    );
  }

  Future<void> _onLoadMy(
      BookingLoadMyEvent event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    _page = 0;
    _filterStatus = event.status;
    final result = await getMyBookings(status: event.status, page: 0);
    result.fold(
      (f) => emit(BookingError(f.message)),
      (paged) => emit(BookingListLoaded(
        bookings: paged.content,
        hasMore: paged.hasNextPage,
        filterStatus: event.status,
      )),
    );
  }

  Future<void> _onLoadMore(
      BookingLoadMoreEvent event, Emitter<BookingState> emit) async {
    final current = state;
    if (current is! BookingListLoaded || !current.hasMore) return;
    _page++;
    final result =
        await getMyBookings(status: _filterStatus, page: _page);
    result.fold(
      (_) {},
      (paged) => emit(current.copyWith(
        bookings: [...current.bookings, ...paged.content],
        hasMore: paged.hasNextPage,
      )),
    );
  }

  Future<void> _onCancel(
      BookingCancelEvent event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    final result = await cancelBooking(event.bookingId);
    result.fold(
      (f) => emit(BookingError(f.message)),
      (booking) => emit(BookingCancelled(booking)),
    );
  }

  Future<void> _onReschedule(
      BookingRescheduleEvent event, Emitter<BookingState> emit) async {
    // Reschedule via repository directly when needed
    emit(BookingLoading());
    emit(const BookingError('Reschedule not yet supported'));
  }
}
