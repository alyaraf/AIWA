import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository _repository;
  VerifyOtpUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String phone,
    required String code,
  }) => _repository.verifyOtp(phone: phone, code: code);
}
