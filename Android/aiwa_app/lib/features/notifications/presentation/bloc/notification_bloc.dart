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
  })  : _repository = repository,
        super(NotificationInitial()) {
    on<NotificationGetUnreadCountEvent>(_onGetCount);
    on<NotificationLoadEvent>(_onLoad);
    on<NotificationLoadMoreEvent>(_onLoadMore);
    on<NotificationMarkReadEvent>(_onMarkRead);
    on<NotificationMarkAllReadEvent>(_onMarkAll);
  }

  Future<void> _onGetCount(
      NotificationGetUnreadCountEvent event,
      Emitter<NotificationState> emit) async {
    final result = await getUnreadCount();
    result.fold(
      (_) {},
      (count) {
        final current = state;
        if (current is NotificationLoaded) {
          emit(current.copyWith(unreadCount: count));
        } else {
          emit(NotificationLoaded(
              notifications: const [], unreadCount: count, hasMore: false));
        }
      },
    );
  }

  Future<void> _onLoad(
      NotificationLoadEvent event, Emitter<NotificationState> emit) async {
    emit(NotificationLoading());
    _page = 0;
    final result = await getNotifications(page: 0);
    result.fold(
      (f) => emit(NotificationError(f.message)),
      (paged) => emit(NotificationLoaded(
        notifications: paged.content,
        unreadCount: paged.content.where((n) => !n.read).length,
        hasMore: paged.hasNextPage,
      )),
    );
  }

  Future<void> _onLoadMore(
      NotificationLoadMoreEvent event,
      Emitter<NotificationState> emit) async {
    final current = state;
    if (current is! NotificationLoaded || !current.hasMore) return;
    _page++;
    final result = await getNotifications(page: _page);
    result.fold(
      (_) {},
      (paged) => emit(current.copyWith(
        notifications: [...current.notifications, ...paged.content],
        hasMore: paged.hasNextPage,
      )),
    );
  }

  Future<void> _onMarkRead(
      NotificationMarkReadEvent event,
      Emitter<NotificationState> emit) async {
    await _repository.markAsRead(event.id);
    final current = state;
    if (current is NotificationLoaded) {
      emit(current.copyWith(
        unreadCount: (current.unreadCount - 1).clamp(0, 999),
      ));
    }
  }

  Future<void> _onMarkAll(
      NotificationMarkAllReadEvent event,
      Emitter<NotificationState> emit) async {
    await _repository.markAllAsRead();
    final current = state;
    if (current is NotificationLoaded) {
      emit(current.copyWith(unreadCount: 0));
    }
  }
}
