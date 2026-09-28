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

  /// One-shot message when an optimistic unsave was rolled back.
  final String? error;

  const SavedLoaded({
    required this.providers,
    required this.hasMore,
    this.error,
  });

  SavedLoaded copyWith({
    List<ProviderSummaryEntity>? providers,
    bool? hasMore,
    String? error,
  }) => SavedLoaded(
    providers: providers ?? this.providers,
    hasMore: hasMore ?? this.hasMore,
    error: error,
  );

  @override
  List<Object?> get props => [providers, hasMore, error];
}

class SavedError extends SavedState {
  final String message;
  const SavedError(this.message);
  @override
  List<Object?> get props => [message];
}
