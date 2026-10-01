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
      final tokens = await _remote.login(
        identifier: identifier,
        password: password,
      );
      _storage.markNewSession();
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
      return const Left(
        ServerFailure(
          "That phone/email and password don't match.",
          statusCode: 401,
        ),
      );
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
    String? preferredLanguage,
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
        preferredLanguage: preferredLanguage,
      );
      _storage.markNewSession();
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
  Future<Either<Failure, void>> changePhone({
    required String phone,
    required String code,
  }) async {
    try {
      final tokens = await _remote.changePhone(phone: phone, code: code);
      // The backend revoked every token issued before the change.
      _storage.markNewSession();
      await _storage.saveAccessToken(tokens['accessToken']!);
      await _storage.saveRefreshToken(tokens['refreshToken']!);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
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
  Future<Either<Failure, void>> updateLanguage({
    required String language,
  }) async {
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
  Future<Either<Failure, void>> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _remote.resetPassword(
        phone: identifier,
        code: code,
        newPassword: newPassword,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> uploadAvatar(String path) async {
    try {
      await _remote.uploadAvatar(path);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> createProviderProfile(
    Map<String, dynamic> profile, {
    List<String> staff = const [],
  }) async {
    try {
      await _remote.createProviderProfile(profile);
      for (final name in staff) {
        await _remote.addStaff(name);
      }
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> uploadVerificationDocuments({
    required String idFront,
    required String idBack,
    required String selfie,
  }) async {
    try {
      await _remote.uploadVerificationDocuments(
        idFront: idFront,
        idBack: idBack,
        selfie: selfie,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, TermsDoc>> latestTerms(
    String type,
  ) => _guard(() async {
    final t = await _remote.latestTerms(type);
    return (
      version: t['version'] as String,
      content: t['contentEn'] as String? ?? '',
      contentAr: t['contentAr'] as String? ?? '',
      pdfUrl: t['pdfUrl'] as String?,
    );
  });

  @override
  Future<Either<Failure, void>> acceptTerms(String version) =>
      _guard(() => _remote.acceptTerms(version));

  @override
  Future<Either<Failure, void>> updatePreferences({
    required double minKm,
    required double maxKm,
  }) => _guard(() => _remote.updatePreferences(minKm: minKm, maxKm: maxKm));

  static Future<Either<Failure, T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
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
