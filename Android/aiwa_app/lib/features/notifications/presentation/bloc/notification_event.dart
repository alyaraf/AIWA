import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class NotificationLoadEvent extends NotificationEvent {}

class NotificationGetUnreadCountEvent extends NotificationEvent {}

class NotificationMarkReadEvent extends NotificationEvent {
  final String id;
  const NotificationMarkReadEvent(this.id);
  @override
  List<Object?> get props => [id];
}

class NotificationMarkAllReadEvent extends NotificationEvent {}

class NotificationLoadMoreEvent extends NotificationEvent {}

/// The signed-in account changed or ended: drop the previous account's inbox (audit M-01).
class NotificationResetEvent extends NotificationEvent {}
