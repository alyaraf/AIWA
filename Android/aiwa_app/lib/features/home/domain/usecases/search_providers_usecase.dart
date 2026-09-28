import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/provider_summary_entity.dart';
import '../repositories/home_repository.dart';

class SearchProvidersUseCase {
  final HomeRepository _repository;
  SearchProvidersUseCase(this._repository);

  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> call({
    required String query,
    int page = 0,
    int size = 20,
  }) => _repository.searchProviders(query: query, page: page, size: size);
}
