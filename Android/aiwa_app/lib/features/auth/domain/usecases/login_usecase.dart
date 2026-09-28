import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;
  LoginUseCase(this._repository);

  Future<Either<Failure, Map<String, String>>> call({
    required String identifier,
    required String password,
  }) => _repository.login(identifier: identifier, password: password);
}
