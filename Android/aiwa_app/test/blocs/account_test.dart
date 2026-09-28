import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:aiwa_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:aiwa_app/features/notifications/domain/usecases/get_notifications_usecase.dart';
import 'package:aiwa_app/features/notifications/domain/usecases/get_unread_count_usecase.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_event.dart';
import 'package:aiwa_app/features/notifications/presentation/bloc/notification_state.dart';
import 'package:aiwa_app/features/notifications/presentation/pages/notification_preferences_page.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationEntity _n(String id) => NotificationEntity(
  id: id,
  title: 'Provider on the way',
  message: 'Nadia is 10 minutes away.',
  type: 'BOOKING_CONFIRMED',
  read: false,
  createdAt: DateTime(2026, 9, 27),
  referenceId: '7',
);

class _FakeRepo implements NotificationRepository {
  final marked = <String>[];

  @override
  Future<Either<Failure, PagedData<NotificationEntity>>> getNotifications({
    int page = 0,
    int size = 20,
  }) async => Right(
    PagedData(
      content: [_n('1'), _n('2'), _n('3')],
      totalElements: 3,
      totalPages: 1,
      number: 0,
      size: 20,
      last: true,
    ),
  );

  @override
  Future<Either<Failure, int>> getUnreadCount() async => const Right(3);

  @override
  Future<Either<Failure, void>> markAsRead(String id) async {
    marked.add(id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllAsRead() async => const Right(null);
}

void main() {
  late _FakeRepo repo;
  late NotificationBloc bloc;

  setUp(() async {
    repo = _FakeRepo();
    bloc = NotificationBloc(
      getNotifications: GetNotificationsUseCase(repo),
      getUnreadCount: GetUnreadCountUseCase(repo),
      repository: repo,
    );
    bloc.add(NotificationLoadEvent());
    await bloc.stream.firstWhere((s) => s is NotificationLoaded);
  });

  tearDown(() => bloc.close());

  List<bool> reads() => (bloc.state as NotificationLoaded).notifications
      .map((n) => n.read)
      .toList();

  test('mark read clears that row and ignores a second tap', () async {
    bloc
      ..add(NotificationMarkReadEvent('2'))
      ..add(NotificationMarkReadEvent('2'));
    await pumpEventQueue();
    expect(reads(), [false, true, false]);
    expect((bloc.state as NotificationLoaded).unreadCount, 2);
    expect(repo.marked, ['2']);
  });

  test('mark all read clears every row', () async {
    bloc.add(NotificationMarkAllReadEvent());
    await pumpEventQueue();
    expect(reads(), [true, true, true]);
    expect((bloc.state as NotificationLoaded).unreadCount, 0);
  });

  test('quiet-hours times parse from every LocalTime shape', () {
    expect(hhmm('22:00:00'), '22:00');
    expect(hhmm('08:00'), '08:00');
    expect(hhmm([7, 5]), '07:05');
    expect(hhmm(null), isNull);
  });
}
