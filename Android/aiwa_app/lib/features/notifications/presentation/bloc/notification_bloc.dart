import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/get_unread_count_usecase.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase getNotifications;
  final GetUnreadCountUseCase getUnreadCount;
  final NotificationRepository _repository;
  int _page = 0;

  NotificationBloc({
    required this.getNotifications,
    required this.getUnreadCount,
    required NotificationRepository repository,
  }) : _repository = repository,
       super(NotificationInitial()) {
    on<NotificationGetUnreadCountEvent>(_onGetCount);
    on<NotificationLoadEvent>(_onLoad);
    on<NotificationLoadMoreEvent>(_onLoadMore);
    on<NotificationMarkReadEvent>(_onMarkRead);
    on<NotificationMarkAllReadEvent>(_onMarkAll);
  }

  Future<void> _onGetCount(
    NotificationGetUnreadCountEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await getUnreadCount();
    result.fold((_) {}, (count) {
      final current = state;
      if (current is NotificationLoaded) {
        emit(current.copyWith(unreadCount: count));
      } else {
        emit(
          NotificationLoaded(
            notifications: const [],
            unreadCount: count,
            hasMore: false,
          ),
        );
      }
    });
  }

  Future<void> _onLoad(
    NotificationLoadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    _page = 0;
    final countFuture = getUnreadCount();
    final result = await getNotifications(page: 0);
    // Server total, not just page 0; page count is the fallback.
    final count = (await countFuture).fold((_) => null, (c) => c);
    result.fold(
      (f) => emit(NotificationError(f.message)),
      (paged) => emit(
        NotificationLoaded(
          notifications: paged.content,
          unreadCount: count ?? paged.content.where((n) => !n.read).length,
          hasMore: paged.hasNextPage,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    NotificationLoadMoreEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded || !current.hasMore) return;
    _page++;
    final result = await getNotifications(page: _page);
    result.fold(
      (_) {},
      (paged) => emit(
        current.copyWith(
          notifications: [...current.notifications, ...paged.content],
          hasMore: paged.hasNextPage,
        ),
      ),
    );
  }

  // Optimistic: the row loses its unread styling before the call returns,
  // and gets it back if the server never saved it.
  Future<void> _onMarkRead(
    NotificationMarkReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is NotificationLoaded) {
      if (current.notifications.any((n) => n.id == event.id && n.read)) return;
      emit(
        current.copyWith(
          notifications: [
            for (final n in current.notifications)
              n.id == event.id ? n.markedRead() : n,
          ],
          unreadCount: (current.unreadCount - 1).clamp(0, 999),
        ),
      );
    }
    final result = await _repository.markAsRead(event.id);
    if (result.isLeft() && current is NotificationLoaded) {
      _restoreUnread(current, {event.id}, emit);
    }
  }

  Future<void> _onMarkAll(
    NotificationMarkAllReadEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is NotificationLoaded) {
      emit(
        current.copyWith(
          notifications: [
            for (final n in current.notifications) n.read ? n : n.markedRead(),
          ],
          unreadCount: 0,
        ),
      );
    }
    final result = await _repository.markAllAsRead();
    if (result.isLeft() && current is NotificationLoaded) {
      _restoreUnread(current, {
        for (final n in current.notifications)
          if (!n.read) n.id,
      }, emit);
    }
  }

  /// Puts [ids] back to their [before] (unread) version in the latest state,
  /// leaving any other rows the user touched meanwhile alone.
  void _restoreUnread(
    NotificationLoaded before,
    Set<String> ids,
    Emitter<NotificationState> emit,
  ) {
    final now = state;
    if (now is! NotificationLoaded || ids.isEmpty) return;
    final original = {
      for (final n in before.notifications)
        if (ids.contains(n.id)) n.id: n,
    };
    final rows = [
      for (final n in now.notifications)
        n.read && original.containsKey(n.id) ? original[n.id]! : n,
    ];
    final restored =
        now.notifications.where((n) => n.read).length -
        rows.where((n) => n.read).length;
    if (restored == 0) return;
    emit(
      now.copyWith(
        notifications: rows,
        unreadCount: now.unreadCount + restored,
      ),
    );
  }
}
