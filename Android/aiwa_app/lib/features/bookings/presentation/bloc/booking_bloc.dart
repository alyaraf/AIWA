import '../../domain/repositories/booking_repository.dart';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/telemetry.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository bookingRepository;

  int _page = 0;
  String? _filterStatus;

  /// SA-13: one load-more at a time.
  bool _loadingMore = false;

  /// M-10: every (re)load starts a new query. Answers (first page or continuation) that belong to an older query
  /// are dropped, so a slow Upcoming answer can no longer overwrite Past, and a continuation can no longer append
  /// the previous filter's rows or move this query's page counter.
  int _query = 0;

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
      (f) => emit(
        BookingError(
          f.message,
          slotTaken: isSlotTaken(f),
          termsOutdated:
              f is ServerFailure && f.code == 'terms.error.not_accepted',
        ),
      ),
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
    final query = ++_query;
    final session = SecureStorage.generation;
    _page = 0;
    _loadingMore = false;
    _filterStatus = event.status;
    final result = await bookingRepository.getMyBookings(status: event.status, page: 0);
    // A newer load took over, or the session changed (M-01): this answer is not for the screen any more.
    if (query != _query || session != SecureStorage.generation) return;
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
    if (current is! BookingListLoaded || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    final query = _query;
    final session = SecureStorage.generation;
    try {
      // SA-13: the page number moves only when its answer arrived; a failed request is
      // asked for again by the next tap instead of skipping a page of bookings.
      final result = await bookingRepository.getMyBookings(status: _filterStatus, page: _page + 1);
      // M-10: only the query that asked may use the answer. Append to the CURRENT state, not the one captured
      // before the request, so nothing that arrived meanwhile is lost.
      if (query != _query || session != SecureStorage.generation) return;
      final latest = state;
      if (latest is! BookingListLoaded) return;
      result.fold(
        (_) {},
        (paged) {
          _page++;
          emit(
            latest.copyWith(
              bookings: [...latest.bookings, ...paged.content],
              hasMore: paged.hasNextPage,
            ),
          );
        },
      );
    } finally {
      // A newer load already reset the flag for its own continuations; do not release theirs.
      if (query == _query) _loadingMore = false;
    }
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
