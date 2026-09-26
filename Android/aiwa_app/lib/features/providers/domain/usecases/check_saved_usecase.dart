import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/provider_repository.dart';

class CheckSavedUseCase {
  final ProviderRepository _repository;
  CheckSavedUseCase(this._repository);

  Future<Either<Failure, bool>> call(String providerId) =>
      _repository.isProviderSaved(providerId);
}
