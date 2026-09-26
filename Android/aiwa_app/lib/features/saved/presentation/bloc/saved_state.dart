import 'package:equatable/equatable.dart';
import '../../../home/domain/entities/provider_summary_entity.dart';

abstract class SavedState extends Equatable {
  const SavedState();
  @override
  List<Object?> get props => [];
}

class SavedInitial extends SavedState {}

class SavedLoading extends SavedState {}

class SavedLoaded extends SavedState {
  final List<ProviderSummaryEntity> providers;
  final bool hasMore;

  const SavedLoaded({required this.providers, required this.hasMore});

  SavedLoaded copyWith({
    List<ProviderSummaryEntity>? providers,
    bool? hasMore,
  }) =>
      SavedLoaded(
        providers: providers ?? this.providers,
        hasMore: hasMore ?? this.hasMore,
      );

  @override
  List<Object?> get props => [providers, hasMore];
}

class SavedError extends SavedState {
  final String message;
  const SavedError(this.message);
  @override
  List<Object?> get props => [message];
}
