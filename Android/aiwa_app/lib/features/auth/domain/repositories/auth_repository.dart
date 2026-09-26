import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, Map<String, String>>> login({
    required String identifier,
    required String password,
  });

  Future<Either<Failure, Map<String, String>>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
  });

  Future<Either<Failure, void>> sendOtp({required String phone});

  Future<Either<Failure, void>> verifyOtp({
    required String phone,
    required String code,
  });

  Future<Either<Failure, UserEntity>> getCurrentUser();

  Future<Either<Failure, UserEntity>> updateProfile({
    String? fullName,
    String? email,
    String? profileImageUrl,
  });

  Future<Either<Failure, void>> updateLanguage({required String language});

  Future<Either<Failure, String>> refreshToken({
    required String refreshToken,
  });
}
