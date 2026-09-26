import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureStorage _storage;

  AuthRepositoryImpl(this._remote, this._storage);

  @override
  Future<Either<Failure, Map<String, String>>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final tokens =
          await _remote.login(identifier: identifier, password: password);
      await _storage.saveAccessToken(tokens['accessToken']!);
      await _storage.saveRefreshToken(tokens['refreshToken']!);
      await _storage.saveUserRole(tokens['role']!);
      await _storage.saveUserId(tokens['userId']!);
      return Right(tokens);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, String>>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
  }) async {
    try {
      final tokens = await _remote.register(
        fullName: fullName,
        password: password,
        email: email,
        phone: phone,
        role: role,
        gender: gender,
        profileImageUrl: profileImageUrl,
      );
      await _storage.saveAccessToken(tokens['accessToken']!);
      await _storage.saveRefreshToken(tokens['refreshToken']!);
      await _storage.saveUserRole(tokens['role']!);
      await _storage.saveUserId(tokens['userId']!);
      return Right(tokens);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> sendOtp({required String phone}) async {
    try {
      await _remote.sendOtp(phone: phone);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    try {
      await _remote.verifyOtp(phone: phone, code: code);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _remote.getCurrentUser();
      return Right(user);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    String? fullName,
    String? email,
    String? profileImageUrl,
  }) async {
    try {
      final user = await _remote.updateProfile(
        fullName: fullName,
        email: email,
        profileImageUrl: profileImageUrl,
      );
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateLanguage({required String language}) async {
    try {
      await _remote.updateLanguage(language: language);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken({
    required String refreshToken,
  }) async {
    try {
      return Right(refreshToken);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
