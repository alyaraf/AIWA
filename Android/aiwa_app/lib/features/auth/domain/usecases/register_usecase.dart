import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  Future<Either<Failure, Map<String, String>>> call({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
  }) =>
      _repository.register(
        fullName: fullName,
        password: password,
        email: email,
        phone: phone,
        role: role,
        gender: gender,
        profileImageUrl: profileImageUrl,
      );
}
