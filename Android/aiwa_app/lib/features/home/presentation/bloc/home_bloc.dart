import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/telemetry.dart';
import '../../domain/usecases/get_nearby_providers_usecase.dart';
import '../../domain/usecases/search_providers_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetNearbyProvidersUseCase getNearbyProviders;
  final SearchProvidersUseCase searchProviders;

  double _lat = 30.0444;
  double _lng = 31.2357;
  double _radiusKm = 5;
  int _page = 0;
  String? _category;

  /// Set while showing name-search results, so Load more pages the search.
  String? _query;

  /// Bumped by every new list request; a response for an older one is
  /// dropped, so a slow "na" can't overwrite the "nail" results.
  int _seq = 0;
  static const int _pageSize = 20;

  HomeBloc({required this.getNearbyProviders, required this.searchProviders})
    : super(HomeInitial()) {
    on<HomeLoadEvent>(_onLoad);
    on<HomeLoadMoreEvent>(_onLoadMore);
    on<HomeCategoryFilterEvent>(_onCategoryFilter);
    on<HomeSearchEvent>(_onSearch);
  }

  Future<void> _onLoad(HomeLoadEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    _lat = event.lat;
    _lng = event.lng;
    _radiusKm = event.radiusKm;
    _category = event.category;
    _page = 0;
    _query = null;
    final seq = ++_seq;

    final result = await getNearbyProviders(
      lat: _lat,
      lng: _lng,
      radiusKm: _radiusKm,
      category: _category,
      page: 0,
      size: _pageSize,
    );
    if (seq != _seq) return;

    result.fold((failure) => emit(HomeError(failure.message)), (paged) {
      final providers = paged.content;
      final trending = providers.take(3).toList();
      emit(
        HomeLoaded(
          providers: providers,
          trending: trending,
          hasMore: paged.hasNextPage,
          selectedCategory: _category,
        ),
      );
    });
  }

  Future<void> _onLoadMore(
    HomeLoadMoreEvent event,
    Emitter<HomeState> emit,
  ) async {
    final current = state;
    if (current is! HomeLoaded || !current.hasMore) return;

    emit(
      HomeLoadingMore(
        providers: current.providers,
        trending: current.trending,
        hasMore: current.hasMore,
        selectedCategory: current.selectedCategory,
      ),
    );

    final seq = _seq;
    final page = _page + 1;
    final query = _query;
    final result = query != null
        ? await searchProviders(query: query, page: page, size: _pageSize)
        : await getNearbyProviders(
            lat: _lat,
            lng: _lng,
            radiusKm: _radiusKm,
            category: _category,
            page: page,
            size: _pageSize,
          );
    if (seq != _seq) return;

    result.fold(
      (failure) => emit(current.copyWith(loadMoreError: failure.message)),
      (paged) {
        _page = page;
        emit(
          current.copyWith(
            providers: [...current.providers, ...paged.content],
            hasMore: paged.hasNextPage,
          ),
        );
      },
    );
  }

  Future<void> _onCategoryFilter(
    HomeCategoryFilterEvent event,
    Emitter<HomeState> emit,
  ) async {
    _category = event.category;
    _page = 0;
    _query = null;
    final seq = ++_seq;
    emit(HomeLoading());
    final result = await getNearbyProviders(
      lat: _lat,
      lng: _lng,
      radiusKm: _radiusKm,
      category: _category,
      page: 0,
      size: _pageSize,
    );
    if (seq != _seq) return;
    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) => emit(
        HomeLoaded(
          providers: paged.content,
          trending: paged.content.take(3).toList(),
          hasMore: paged.hasNextPage,
          selectedCategory: _category,
        ),
      ),
    );
  }

  Future<void> _onSearch(HomeSearchEvent event, Emitter<HomeState> emit) async {
    _query = event.query;
    _page = 0;
    final seq = ++_seq;
    emit(HomeLoading());
    trackFunnel('search'); // not the query: it can hold names
    final result = await searchProviders(query: event.query, size: _pageSize);
    if (seq != _seq) return;
    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) => emit(
        HomeLoaded(
          providers: paged.content,
          trending: [],
          hasMore: paged.hasNextPage,
          selectedCategory: null,
        ),
      ),
    );
  }
}
