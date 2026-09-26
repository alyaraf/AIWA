import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/provider_detail_entity.dart';
import '../repositories/provider_repository.dart';

class GetProviderDetailUseCase {
  final ProviderRepository _repository;
  GetProviderDetailUseCase(this._repository);

  Future<Either<Failure, ProviderDetailEntity>> call(String providerId) =>
      _repository.getProviderDetail(providerId);
}
