import 'package:equatable/equatable.dart';

abstract class SavedEvent extends Equatable {
  const SavedEvent();
  @override
  List<Object?> get props => [];
}

class SavedLoadEvent extends SavedEvent {}

class SavedLoadMoreEvent extends SavedEvent {}

class SavedRemoveEvent extends SavedEvent {
  final String providerId;
  const SavedRemoveEvent(this.providerId);
  @override
  List<Object?> get props => [providerId];
}
