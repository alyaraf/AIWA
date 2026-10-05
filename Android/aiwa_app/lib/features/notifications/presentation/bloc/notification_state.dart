import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final bool hasMore;

  /// The last "Load more" failed (null otherwise): the list stays, the footer offers a retry, and the same page
  /// is asked for again (M-11).
  final String? loadMoreError;

  /// A continuation request is in flight.
  final bool loadingMore;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.loadMoreError,
    this.loadingMore = false,
  });

  NotificationLoaded copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    bool? hasMore,
    Object? loadMoreError = _keep,
    bool? loadingMore,
  }) => NotificationLoaded(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    hasMore: hasMore ?? this.hasMore,
    loadMoreError: identical(loadMoreError, _keep)
        ? this.loadMoreError
        : loadMoreError as String?,
    loadingMore: loadingMore ?? this.loadingMore,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    notifications,
    unreadCount,
    hasMore,
    loadMoreError,
    loadingMore,
  ];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
  @override
  List<Object?> get props => [message];
}
