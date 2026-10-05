// M-10: list/filter changes and continuations carry a query generation; M-02: the Upcoming query is the live
// statuses, asked of the server.
import 'dart:async';

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

BookingModel _b(int id, String status) => BookingModel.fromJson({
  'id': id,
  'provider': {'id': 12, 'businessName': 'Nadia Studio'},
  'service': {'id': 3, 'name': 'Blowout'},
  'bookingDate': '2026-05-19',
  'startTime': '12:30:00',
  'status': status,
  'totalPrice': 350,
});

PagedData<BookingEntity> _page(List<BookingModel> rows, {required bool last, int number = 0}) => PagedData(
  content: rows,
  totalElements: 99,
  totalPages: 9,
  number: number,
  size: rows.length,
  last: last,
);

/// Every request waits for the test to answer it, so the test chooses the order of completion.
class _Repo implements BookingRepository {
  final requests = <({String? status, int page, Completer<Either<Failure, PagedData<BookingEntity>>> done})>[];

  @override
  Future<Either<Failure, PagedData<BookingEntity>>> getMyBookings({
    String? status,
    int page = 0,
    int size = 20,
  }) {
    final c = Completer<Either<Failure, PagedData<BookingEntity>>>();
    requests.add((status: status, page: page, done: c));
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _spin() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Repo repo;
  late BookingBloc bloc;
  late List<BookingState> states;

  setUp(() {
    repo = _Repo();
    bloc = BookingBloc(bookingRepository: repo);
    states = [];
    bloc.stream.listen(states.add);
  });
  tearDown(() => bloc.close());

  test('M-10: Upcoming answering after Past (reversed completion) does not overwrite Past', () async {
    bloc.add(const BookingLoadMyEvent(status: 'PENDING,ACCEPTED')); // Upcoming
    await _spin();
    bloc.add(const BookingLoadMyEvent(status: 'COMPLETED')); // switched to Past
    await _spin();

    repo.requests[1].done.complete(Right(_page([_b(2, 'COMPLETED')], last: true))); // Past first
    await _spin();
    repo.requests[0].done.complete(Right(_page([_b(1, 'ACCEPTED')], last: true))); // Upcoming last
    await _spin();

    final loaded = states.whereType<BookingListLoaded>().last;
    expect(loaded.filterStatus, 'COMPLETED');
    expect(loaded.bookings.map((b) => b.id), ['2']);
    expect(states.whereType<BookingListLoaded>().map((s) => s.filterStatus), everyElement('COMPLETED'));
  });

  test('M-10: a continuation of the previous filter is ignored and does not move the page counter', () async {
    bloc.add(const BookingLoadMyEvent(status: 'PENDING')); // query 1
    await _spin();
    repo.requests[0].done.complete(Right(_page([_b(1, 'PENDING')], last: false)));
    await _spin();

    bloc.add(BookingLoadMoreEvent()); // page 1 of query 1 is in flight...
    await _spin();
    bloc.add(const BookingLoadMyEvent(status: 'COMPLETED')); // ...and the user switches tab
    await _spin();
    repo.requests[2].done.complete(Right(_page([_b(7, 'COMPLETED')], last: false))); // new first page
    await _spin();
    repo.requests[1].done.complete(Right(_page([_b(2, 'PENDING')], last: false, number: 1))); // late old page 1
    await _spin();

    final loaded = states.whereType<BookingListLoaded>().last;
    expect(loaded.filterStatus, 'COMPLETED');
    expect(loaded.bookings.map((b) => b.id), ['7']); // no row of the old filter was appended

    bloc.add(BookingLoadMoreEvent()); // the next continuation is page 1 of the NEW query, not page 2
    await _spin();
    expect(repo.requests.last.status, 'COMPLETED');
    expect(repo.requests.last.page, 1);
  });

  test('M-10: a continuation that arrives for the current query is still appended', () async {
    bloc.add(const BookingLoadMyEvent(status: 'PENDING'));
    await _spin();
    repo.requests[0].done.complete(Right(_page([_b(1, 'PENDING')], last: false)));
    await _spin();
    bloc.add(BookingLoadMoreEvent());
    await _spin();
    repo.requests[1].done.complete(Right(_page([_b(2, 'PENDING')], last: true, number: 1)));
    await _spin();
    expect((bloc.state as BookingListLoaded).bookings.map((b) => b.id), ['1', '2']);
  });

  test('M-10: two taps of Load more while one is in flight send one request', () async {
    bloc.add(const BookingLoadMyEvent());
    await _spin();
    repo.requests[0].done.complete(Right(_page([_b(1, 'PENDING')], last: false)));
    await _spin();
    bloc.add(BookingLoadMoreEvent());
    bloc.add(BookingLoadMoreEvent());
    await _spin();
    expect(repo.requests.where((r) => r.page == 1), hasLength(1));
  });
}
