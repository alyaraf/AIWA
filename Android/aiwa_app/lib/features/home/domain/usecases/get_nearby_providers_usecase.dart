import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/provider_summary_entity.dart';
import '../repositories/home_repository.dart';

class GetNearbyProvidersUseCase {
  final HomeRepository _repository;
  GetNearbyProvidersUseCase(this._repository);

  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> call({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  }) =>
      _repository.getNearbyProviders(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        category: category,
        sort: sort,
        page: page,
        size: size,
      );
}
