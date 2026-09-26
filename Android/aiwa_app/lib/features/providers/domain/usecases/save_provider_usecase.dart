import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/provider_repository.dart';

class SaveProviderUseCase {
  final ProviderRepository _repository;
  SaveProviderUseCase(this._repository);

  Future<Either<Failure, void>> save(String providerId) =>
      _repository.saveProvider(providerId);

  Future<Either<Failure, void>> unsave(String providerId) =>
      _repository.unsaveProvider(providerId);
}
