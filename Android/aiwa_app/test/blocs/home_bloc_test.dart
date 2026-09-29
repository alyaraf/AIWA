import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/features/home/domain/entities/provider_summary_entity.dart';
import 'package:aiwa_app/features/home/domain/repositories/home_repository.dart';
import 'package:aiwa_app/features/home/domain/usecases/get_nearby_providers_usecase.dart';
import 'package:aiwa_app/features/home/domain/usecases/search_providers_usecase.dart';
import 'package:aiwa_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:aiwa_app/features/home/presentation/bloc/home_event.dart';
import 'package:aiwa_app/features/home/presentation/bloc/home_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// FE-35: Load more pages the search, a stale search is dropped, and a
/// failed Load more keeps the list.
void main() {
  late _Repo repo;
  late HomeBloc bloc;

  setUp(() {
    repo = _Repo();
    bloc = HomeBloc(
      getNearbyProviders: GetNearbyProvidersUseCase(repo),
      searchProviders: SearchProvidersUseCase(repo),
    );
  });
  tearDown(() => bloc.close());

  Future<HomeLoaded> settled() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return bloc.state as HomeLoaded;
  }

  test('Load more after a search pages the search, not nearby', () async {
    bloc.add(const HomeSearchEvent('nail'));
    await settled();
    bloc.add(HomeLoadMoreEvent());
    final s = await settled();
    expect(s.providers.map((p) => p.businessName), ['nail#0', 'nail#1']);
  });

  test('an older, slower search does not overwrite a newer one', () async {
    repo.slow = 'na';
    bloc.add(const HomeSearchEvent('na'));
    bloc.add(const HomeSearchEvent('nail'));
    final s = await settled();
    expect(s.providers.single.businessName, 'nail#0');
  });

  test('a failed Load more keeps the list with an inline error', () async {
    bloc.add(const HomeSearchEvent('nail'));
    await settled();
    repo.fail = true;
    bloc.add(HomeLoadMoreEvent());
    final s = await settled();
    expect(s.providers.single.businessName, 'nail#0');
    expect(s.loadMoreError, 'down');
  });
}

class _Repo implements HomeRepository {
  String? slow;
  bool fail = false;

  Either<Failure, PagedData<ProviderSummaryEntity>> _page(String q, int n) =>
      fail
      ? const Left(ServerFailure('down'))
      : Right(
          PagedData(
            content: [
              ProviderSummaryEntity(
                id: n,
                businessName: '$q#$n',
                primaryCategory: 'HAIR',
                totalReviews: 0,
                verificationStatus: 'VERIFIED',
                ownerName: 'o',
              ),
            ],
            totalElements: 10,
            totalPages: 10,
            number: n,
            size: 1,
            last: false,
          ),
        );

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> searchProviders({
    required String query,
    int page = 0,
    int size = 20,
  }) async {
    if (query == slow) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return _page(query, page);
  }

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  }) async => _page('nearby', page);

  @override
  Future<Either<Failure, void>> notifyWhenProviderJoins({
    String? category,
    double? lat,
    double? lng,
  }) async => const Right(null);
}
