import 'package:equatable/equatable.dart';
import '../../domain/entities/provider_summary_entity.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<ProviderSummaryEntity> providers;
  final List<ProviderSummaryEntity> trending;
  final bool hasMore;
  final String? selectedCategory;

  /// A failed "Load more": the list stays, the error shows inline.
  final String? loadMoreError;

  const HomeLoaded({
    required this.providers,
    required this.trending,
    required this.hasMore,
    this.selectedCategory,
    this.loadMoreError,
  });

  /// Clears [loadMoreError] unless one is passed.
  HomeLoaded copyWith({
    List<ProviderSummaryEntity>? providers,
    List<ProviderSummaryEntity>? trending,
    bool? hasMore,
    String? selectedCategory,
    String? loadMoreError,
  }) => HomeLoaded(
    providers: providers ?? this.providers,
    trending: trending ?? this.trending,
    hasMore: hasMore ?? this.hasMore,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    loadMoreError: loadMoreError,
  );

  @override
  List<Object?> get props => [
    providers,
    trending,
    hasMore,
    selectedCategory,
    loadMoreError,
  ];
}

class HomeLoadingMore extends HomeLoaded {
  const HomeLoadingMore({
    required super.providers,
    required super.trending,
    required super.hasMore,
    super.selectedCategory,
  });
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}
