import '../../domain/repositories/booking_repository.dart';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/telemetry.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository bookingRepository;

  int _page = 0;
  String? _filterStatus;

  /// One Idempotency-Key per booking attempt: a retry of the same request
  /// (e.g. after a timeout) reuses it, so the backend returns the first
  /// booking instead of creating a second one.
  BookingCreateEvent? _attempt;
  String _attemptKey = '';

  BookingBloc({
    required this.bookingRepository,
  }) : super(BookingInitial()) {
    on<BookingCreateEvent>(_onCreate);
    on<BookingLoadMyEvent>(_onLoadMy);
    on<BookingLoadMoreEvent>(_onLoadMore);
    on<BookingCancelEvent>(_onCancel);
  }

  Future<void> _onCreate(
    BookingCreateEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    if (event != _attempt) {
      _attempt = event;
      _attemptKey = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    }
    final result = await bookingRepository.createBooking(
      providerId: event.providerId,
      serviceId: event.serviceId,
      scheduledDate: event.scheduledDate,
      scheduledTime: event.scheduledTime,
      staffId: event.staffId,
      bookNow: event.bookNow,
      homeService: event.homeService,
      savedAddressId: event.savedAddressId,
      customerNote: event.customerNote,
      idempotencyKey: _attemptKey,
    );
    result.fold(
      (f) => emit(BookingError(f.message, slotTaken: isSlotTaken(f))),
      (booking) {
        _attempt = null;
        trackFunnel('book', bookingId: booking.id);
        emit(BookingCreated(booking));
      },
    );
  }

  Future<void> _onLoadMy(
    BookingLoadMyEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    _page = 0;
    _filterStatus = event.status;
    final result = await bookingRepository.getMyBookings(status: event.status, page: 0);
    result.fold(
      (f) => emit(BookingError(f.message)),
      (paged) => emit(
        BookingListLoaded(
          bookings: paged.content,
          hasMore: paged.hasNextPage,
          filterStatus: event.status,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    BookingLoadMoreEvent event,
    Emitter<BookingState> emit,
  ) async {
    final current = state;
    if (current is! BookingListLoaded || !current.hasMore) return;
    _page++;
    final result = await bookingRepository.getMyBookings(status: _filterStatus, page: _page);
    result.fold(
      (_) {},
      (paged) => emit(
        current.copyWith(
          bookings: [...current.bookings, ...paged.content],
          hasMore: paged.hasNextPage,
        ),
      ),
    );
  }

  Future<void> _onCancel(
    BookingCancelEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    final result = await bookingRepository.cancelBooking(event.bookingId);
    result.fold(
      (f) => emit(BookingError(f.message)),
      (booking) => emit(BookingCancelled(booking)),
    );
  }
}

/// The backend reports a taken slot as HTTP 400 BusinessException
/// 'booking.error.conflict', not 409.
// ponytail: matches messages_en/ar.properties text (the app sends
// Accept-Language). Drop the text match once the backend sends 409 or an
// errorCode.
bool isSlotTaken(Failure f) =>
    f is ServerFailure &&
    (f.statusCode == 409 ||
        f.message.startsWith('This time slot is already booked') ||
        f.message.startsWith('هذا الموعد محجوز بالفعل'));
