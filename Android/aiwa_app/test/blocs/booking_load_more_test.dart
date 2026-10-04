// SA-13: a failed load-more must not skip a page of bookings.
import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/features/bookings/data/models/booking_model.dart';
import 'package:aiwa_app/features/bookings/domain/entities/booking_entity.dart';
import 'package:aiwa_app/features/bookings/domain/repositories/booking_repository.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/booking_bloc.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/booking_event.dart';
import 'package:aiwa_app/features/bookings/presentation/bloc/booking_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

BookingModel _b(int id) => BookingModel.fromJson({
  'id': id,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': 'ACCEPTED',
  'totalPrice': 350,
});

PagedData<BookingEntity> _page(int n, {required bool last}) => PagedData(
  content: [_b(n)],
  totalElements: 3,
  totalPages: 3,
  number: n,
  size: 1,
  last: last,
);

class _Repo implements BookingRepository {
  final asked = <int>[];
  bool failPage1 = true;

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    asked.add(page);
    if (page == 1 && failPage1) return const Left(NetworkFailure('offline'));
    return Right(_page(page, last: page == 2));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('a failed load-more asks for the same page again, never the next one', () async {
    final repo = _Repo();
    final bloc = BookingBloc(bookingRepository: repo);
    bloc.add(const BookingLoadMyEvent());
    await bloc.stream.firstWhere((s) => s is BookingListLoaded);

    bloc.add(BookingLoadMoreEvent());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    repo.failPage1 = false;
    bloc.add(BookingLoadMoreEvent());
    await bloc.stream.firstWhere((s) => s is BookingListLoaded && s.bookings.length == 2);
    bloc.add(BookingLoadMoreEvent());
    await bloc.stream.firstWhere((s) => s is BookingListLoaded && s.bookings.length == 3);

    expect(repo.asked, [0, 1, 1, 2]);
    expect((bloc.state as BookingListLoaded).bookings.map((b) => b.id), ['0', '1', '2']);
    await bloc.close();
  });
}
