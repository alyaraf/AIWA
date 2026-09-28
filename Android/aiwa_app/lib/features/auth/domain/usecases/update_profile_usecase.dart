import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class UpdateProfileUseCase {
  final AuthRepository _repository;
  UpdateProfileUseCase(this._repository);

  Future<Either<Failure, UserEntity>> call({
    String? fullName,
    String? email,
    String? profileImageUrl,
  }) => _repository.updateProfile(
    fullName: fullName,
    email: email,
    profileImageUrl: profileImageUrl,
  );
}
