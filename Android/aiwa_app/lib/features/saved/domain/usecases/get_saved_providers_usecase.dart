import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../home/domain/entities/provider_summary_entity.dart';
import '../repositories/saved_repository.dart';

class GetSavedProvidersUseCase {
  final SavedRepository _repository;
  GetSavedProvidersUseCase(this._repository);

  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> call({
    int page = 0,
    int size = 20,
  }) => _repository.getSavedProviders(page: page, size: size);
}
