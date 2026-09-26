import 'package:equatable/equatable.dart';

abstract class ProviderEvent extends Equatable {
  const ProviderEvent();
  @override
  List<Object?> get props => [];
}

class ProviderLoadEvent extends ProviderEvent {
  final String providerId;
  const ProviderLoadEvent(this.providerId);
  @override
  List<Object?> get props => [providerId];
}

class ProviderToggleSaveEvent extends ProviderEvent {
  final String providerId;
  const ProviderToggleSaveEvent(this.providerId);
  @override
  List<Object?> get props => [providerId];
}

class ProviderLoadSlotsEvent extends ProviderEvent {
  final String providerId;
  final String date;
  const ProviderLoadSlotsEvent(this.providerId, this.date);
  @override
  List<Object?> get props => [providerId, date];
}
