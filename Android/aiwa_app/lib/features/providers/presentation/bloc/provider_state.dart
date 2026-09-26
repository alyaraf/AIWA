import 'package:equatable/equatable.dart';
import '../../domain/entities/provider_detail_entity.dart';

abstract class ProviderState extends Equatable {
  const ProviderState();
  @override
  List<Object?> get props => [];
}

class ProviderInitial extends ProviderState {}

class ProviderLoading extends ProviderState {}

class ProviderLoaded extends ProviderState {
  final ProviderDetailEntity provider;
  final bool isSaved;
  final List<AvailabilitySlot> slots;

  const ProviderLoaded({
    required this.provider,
    required this.isSaved,
    this.slots = const [],
  });

  ProviderLoaded copyWith({
    ProviderDetailEntity? provider,
    bool? isSaved,
    List<AvailabilitySlot>? slots,
  }) =>
      ProviderLoaded(
        provider: provider ?? this.provider,
        isSaved: isSaved ?? this.isSaved,
        slots: slots ?? this.slots,
      );

  @override
  List<Object?> get props => [provider, isSaved, slots];
}

class ProviderError extends ProviderState {
  final String message;
  const ProviderError(this.message);
  @override
  List<Object?> get props => [message];
}
