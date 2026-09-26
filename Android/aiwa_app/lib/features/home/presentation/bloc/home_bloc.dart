import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_nearby_providers_usecase.dart';
import '../../domain/usecases/search_providers_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetNearbyProvidersUseCase getNearbyProviders;
  final SearchProvidersUseCase searchProviders;

  double _lat = 30.0444;
  double _lng = 31.2357;
  int _page = 0;
  String? _category;
  static const int _pageSize = 20;

  HomeBloc({
    required this.getNearbyProviders,
    required this.searchProviders,
  }) : super(HomeInitial()) {
    on<HomeLoadEvent>(_onLoad);
    on<HomeLoadMoreEvent>(_onLoadMore);
    on<HomeCategoryFilterEvent>(_onCategoryFilter);
    on<HomeSearchEvent>(_onSearch);
  }

  Future<void> _onLoad(HomeLoadEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    _lat = event.lat;
    _lng = event.lng;
    _category = event.category;
    _page = 0;

    final result = await getNearbyProviders(
      lat: _lat,
      lng: _lng,
      radiusKm: 10,
      category: _category,
      page: 0,
      size: _pageSize,
    );

    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) {
        final providers = paged.content;
        final trending = providers.take(3).toList();
        emit(HomeLoaded(
          providers: providers,
          trending: trending,
          hasMore: paged.hasNextPage,
          selectedCategory: _category,
        ));
      },
    );
  }

  Future<void> _onLoadMore(
      HomeLoadMoreEvent event, Emitter<HomeState> emit) async {
    final current = state;
    if (current is! HomeLoaded || !current.hasMore) return;

    emit(HomeLoadingMore(
      providers: current.providers,
      trending: current.trending,
      hasMore: current.hasMore,
      selectedCategory: current.selectedCategory,
    ));

    _page++;
    final result = await getNearbyProviders(
      lat: _lat,
      lng: _lng,
      radiusKm: 10,
      category: _category,
      page: _page,
      size: _pageSize,
    );

    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) => emit(current.copyWith(
        providers: [...current.providers, ...paged.content],
        hasMore: paged.hasNextPage,
      )),
    );
  }

  Future<void> _onCategoryFilter(
      HomeCategoryFilterEvent event, Emitter<HomeState> emit) async {
    _category = event.category;
    _page = 0;
    emit(HomeLoading());
    final result = await getNearbyProviders(
      lat: _lat,
      lng: _lng,
      radiusKm: 10,
      category: _category,
      page: 0,
      size: _pageSize,
    );
    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) => emit(HomeLoaded(
        providers: paged.content,
        trending: paged.content.take(3).toList(),
        hasMore: paged.hasNextPage,
        selectedCategory: _category,
      )),
    );
  }

  Future<void> _onSearch(
      HomeSearchEvent event, Emitter<HomeState> emit) async {
    emit(HomeLoading());
    final result = await searchProviders(query: event.query);
    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (paged) => emit(HomeLoaded(
        providers: paged.content,
        trending: [],
        hasMore: paged.hasNextPage,
        selectedCategory: null,
      )),
    );
  }
}
