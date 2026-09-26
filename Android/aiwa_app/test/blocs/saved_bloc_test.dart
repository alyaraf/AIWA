import 'package:aiwa_app/core/errors/failures.dart';
import 'package:aiwa_app/core/network/api_response.dart';
import 'package:aiwa_app/features/home/domain/entities/provider_summary_entity.dart';
import 'package:aiwa_app/features/saved/domain/repositories/saved_repository.dart';
import 'package:aiwa_app/features/saved/domain/usecases/get_saved_providers_usecase.dart';
import 'package:aiwa_app/features/saved/presentation/bloc/saved_bloc.dart';
import 'package:aiwa_app/features/saved/presentation/bloc/saved_event.dart';
import 'package:aiwa_app/features/saved/presentation/bloc/saved_state.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderSummaryEntity _p(int id, String name) => ProviderSummaryEntity(
  id: id,
  businessName: name,
  primaryCategory: 'HAIR',
  totalReviews: 10,
  verificationStatus: 'APPROVED',
  ownerName: name,
);

class _FakeSavedRepository implements SavedRepository {
  final removed = <String>[];

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getSavedProviders({
    int page = 0,
    int size = 20,
  }) async {
    return Right(
      PagedData(
        content: [_p(1, 'Nadia Studio'), _p(2, 'Layla Beauty')],
        totalElements: 2,
        totalPages: 1,
        number: 0,
        size: 20,
        last: true,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> removeProvider(String providerId) async {
    removed.add(providerId);
    return const Right(null);
  }
}

void main() {
  test('removing a saved provider drops it from the list', () async {
    final repo = _FakeSavedRepository();
    final bloc = SavedBloc(
      getSavedProviders: GetSavedProvidersUseCase(repo),
      repository: repo,
    );

    bloc.add(SavedLoadEvent());
    await bloc.stream.firstWhere((s) => s is SavedLoaded);

    // The page passes the id as a String; entity ids are ints.
    bloc.add(const SavedRemoveEvent('1'));
    final after =
        await bloc.stream
                .firstWhere((s) => s is SavedLoaded && s.providers.length == 1)
                .timeout(const Duration(seconds: 2))
            as SavedLoaded;

    expect(repo.removed, ['1']);
    expect(after.providers.single.businessName, 'Layla Beauty');
    await bloc.close();
  });
}
