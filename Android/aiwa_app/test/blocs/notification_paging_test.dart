// M-11: notification continuation never skips a page after a failure and never races with itself; M-01: the inbox
// of a previous account is dropped.
import 'dart:async';

import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:aiwa_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_event.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationEntity _n(int i) => NotificationEntity(
  id: '$i',
  title: 't$i',
  message: 'm$i',
  type: 'BOOKING_CREATED',
  read: false,
  createdAt: DateTime(2026, 5, 19),
);

PagedData<NotificationEntity> _page(List<int> ids, {required bool last, required int number}) => PagedData(
  content: [for (final i in ids) _n(i)],
  totalElements: 99,
  totalPages: 9,
  number: number,
  size: ids.length,
  last: last,
);

class _Repo implements NotificationRepository {
  final requests = <({int page, Completer<Either<Failure, PagedData<NotificationEntity>>> done})>[];

  @override
  Future<Either<Failure, PagedData<NotificationEntity>>> getNotifications({int page = 0, int size = 20}) {
    final c = Completer<Either<Failure, PagedData<NotificationEntity>>>();
    requests.add((page: page, done: c));
    return c.future;
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async => const Right(5);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _spin() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Repo repo;
  late NotificationBloc bloc;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    repo = _Repo();
    bloc = NotificationBloc(repository: repo);
    bloc.add(NotificationLoadEvent());
    await _spin();
    repo.requests[0].done.complete(Right(_page([1, 2], last: false, number: 0)));
    await _spin();
  });
  tearDown(() => bloc.close());

  NotificationLoaded loaded() => bloc.state as NotificationLoaded;

  test('a failed continuation asks for the SAME page again and says so', () async {
    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    expect(repo.requests[1].page, 1);
    repo.requests[1].done.complete(const Left(NetworkFailure('offline')));
    await _spin();
    expect(loaded().loadMoreError, isNotNull);
    expect(loaded().loadingMore, isFalse);
    expect(loaded().notifications, hasLength(2)); // the list stays

    bloc.add(NotificationLoadMoreEvent()); // retry
    await _spin();
    expect(repo.requests[2].page, 1); // not page 2
    repo.requests[2].done.complete(Right(_page([3, 4], last: true, number: 1)));
    await _spin();
    expect(loaded().notifications.map((n) => n.id), ['1', '2', '3', '4']);
    expect(loaded().loadMoreError, isNull);
    expect(loaded().hasMore, isFalse);
  });

  test('overlapping taps send one request and cannot replace each other', () async {
    bloc.add(NotificationLoadMoreEvent());
    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    expect(repo.requests.where((r) => r.page == 1), hasLength(1));
    repo.requests[1].done.complete(Right(_page([3], last: false, number: 1)));
    await _spin();
    expect(loaded().notifications.map((n) => n.id), ['1', '2', '3']);

    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    expect(repo.requests.last.page, 2);
  });

  test('rows already shown are not repeated when the pages shift', () async {
    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    repo.requests[1].done.complete(Right(_page([2, 3], last: true, number: 1))); // 2 moved onto page 1
    await _spin();
    expect(loaded().notifications.map((n) => n.id), ['1', '2', '3']);
  });

  test('M-01: a page that arrives after the account changed is dropped, and a reset empties the inbox', () async {
    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    bloc.add(NotificationResetEvent()); // account switch
    await _spin();
    expect(bloc.state, isA<NotificationInitial>());

    repo.requests[1].done.complete(Right(_page([3], last: true, number: 1))); // the old account's answer
    await _spin();
    expect(bloc.state, isA<NotificationInitial>());
  });

  test('M-01: an answer from before a sign-out is dropped even without a reset', () async {
    bloc.add(NotificationLoadMoreEvent());
    await _spin();
    await SecureStorage(const FlutterSecureStorage()).clearAll(); // session ended
    repo.requests[1].done.complete(Right(_page([3], last: true, number: 1)));
    await _spin();
    expect(loaded().notifications.map((n) => n.id), ['1', '2']);
  });
}
