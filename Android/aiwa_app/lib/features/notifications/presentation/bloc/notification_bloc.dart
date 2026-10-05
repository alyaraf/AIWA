import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  /// The last page that was actually received. Continuation asks for `_page + 1` and only moves this after the
  /// answer arrived, so a failed request is repeated instead of skipping a page (M-11).
  int _page = 0;

  /// Bumped by every (re)load and session change: an answer for an older list is dropped (M-10/M-11 pattern).
  int _list = 0;

  NotificationBloc({
    required this._repository,
  }) : super(NotificationInitial()) {
    on<NotificationGetUnreadCountEvent>(_onGetCount);
    on<NotificationLoadEvent>(_onLoad);
    on<NotificationLoadMoreEvent>(_onLoadMore);
    on<NotificationMarkReadEvent>(_onMarkRead);
    on<NotificationMarkAllReadEvent>(_onMarkAll);
    on<NotificationResetEvent>(_onReset);
  }

  /// The signed-in account changed (sign-out / another account): forget everything of the previous one, and make
  /// any answer still in flight for it harmless (M-01).
  void _onReset(NotificationResetEvent event, Emitter<NotificationState> emit) {
    _list++;
    _page = 0;
    emit(NotificationInitial());
  }

  Future<void> _onGetCount(
    NotificationGetUnreadCountEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await _repository.getUnreadCount();
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
    final list = ++_list;
    final session = SecureStorage.generation;
    _page = 0;
    final countFuture = _repository.getUnreadCount();
    final result = await _repository.getNotifications(page: 0);
    // Server total, not just page 0; page count is the fallback.
    final count = (await countFuture).fold((_) => null, (c) => c);
    if (list != _list || session != SecureStorage.generation) return;
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
    // One continuation at a time: a second tap while one is in flight used to capture the same list and append
    // out of order, or replace the page that arrived first.
    if (current is! NotificationLoaded || !current.hasMore || current.loadingMore) {
      return;
    }
    final list = _list;
    final session = SecureStorage.generation;
    emit(current.copyWith(loadingMore: true, loadMoreError: null));
    final result = await _repository.getNotifications(page: _page + 1);
    if (list != _list || session != SecureStorage.generation) return;
    final latest = state;
    if (latest is! NotificationLoaded) return;
    result.fold(
      // Stay on this page and say so: the next tap asks for the same one again.
      (failure) => emit(latest.copyWith(loadingMore: false, loadMoreError: failure.message)),
      (paged) {
        _page++;
        // Rows already shown (a new notification pushed an old one onto the next page) are not repeated.
        final known = {for (final n in latest.notifications) n.id};
        emit(
          latest.copyWith(
            notifications: [
              ...latest.notifications,
              ...paged.content.where((n) => !known.contains(n.id)),
            ],
            hasMore: paged.hasNextPage,
            loadingMore: false,
            loadMoreError: null,
          ),
        );
      },
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
