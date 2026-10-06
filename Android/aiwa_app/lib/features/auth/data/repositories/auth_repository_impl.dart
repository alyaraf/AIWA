import 'dart:convert';

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

  /// R4-05: ends a server session whose tokens were issued but must not be kept on this phone (the sign-in that
  /// obtained them was overtaken by a newer sign-in / sign-out). Best effort; null in unit tests.
  final Future<void> Function({String? accessToken, String? refreshToken})?
  revokeTokens;

  AuthRepositoryImpl(this._remote, this._storage, {this.revokeTokens});

  /// Stores the tokens of a completed sign-in / registration, but only if that operation is still the current one
  /// (R4-05). Everything runs under the credential lock so another operation's writes cannot interleave. An obsolete
  /// operation stores nothing, ends the session it just opened on the server, and reports [SessionChangedFailure]:
  /// the same meaning as an answer for a session that has ended (never an ordinary failure).
  Future<Either<Failure, Map<String, String>>> _storeSignIn(
    Map<String, String> tokens,
    int attempt,
  ) => _storage.withCredentialLock<Either<Failure, Map<String, String>>>(() async {
    if (!SecureStorage.isCurrentAttempt(attempt)) {
      await _revokeOrphan(tokens);
      return const Left(SessionChangedFailure());
    }
    _storage.markNewSession();
    await _storage.saveAccessToken(tokens['accessToken']!);
    await _storage.saveRefreshToken(tokens['refreshToken']!);
    await _storage.saveUserRole(tokens['role']!);
    await _storage.saveUserId(tokens['userId']!);
    return Right(tokens);
  });

  Future<void> _revokeOrphan(Map<String, String> tokens) async {
    try {
      await revokeTokens?.call(
        accessToken: tokens['accessToken'],
        refreshToken: tokens['refreshToken'],
      );
    } catch (_) {}
  }

  @override
  Future<Either<Failure, Map<String, String>>> login({
    required String identifier,
    required String password,
  }) async {
    // The caller (AuthBloc) began this attempt just before calling.
    final attempt = SecureStorage.authAttempt;
    try {
      final tokens = await _remote.login(
        identifier: identifier,
        password: password,
      );
      return await _storeSignIn(tokens, attempt);
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
    final attempt = SecureStorage.authAttempt;
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
      return await _storeSignIn(tokens, attempt);
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
    required String currentPassword,
  }) => _replaceTokens(
    () => _remote.changePhone(
      phone: phone,
      code: code,
      currentPassword: currentPassword,
    ),
  );

  @override
  Future<Either<Failure, void>> verifyEmail({required String code}) =>
      _replaceTokens(() => _remote.verifyEmail(code: code));

  Future<Either<Failure, void>> _replaceTokens(
    Future<Map<String, String>> Function() call,
  ) async {
    // The tokens replace THIS session's: if the session ended or another sign-in started while the call was running,
    // they belong to nobody on this phone any more (R4-05).
    final session = SecureStorage.generation;
    final attempt = SecureStorage.authAttempt;
    try {
      final tokens = await call();
      return await _storage.withCredentialLock<Either<Failure, void>>(() async {
        if (session != SecureStorage.generation ||
            !SecureStorage.isCurrentAttempt(attempt)) {
          await _revokeOrphan(tokens);
          return const Left(SessionChangedFailure());
        }
        // The backend revoked every token issued before the change.
        _storage.markNewSession();
        await _storage.saveAccessToken(tokens['accessToken']!);
        await _storage.saveRefreshToken(tokens['refreshToken']!);
        return const Right(null);
      });
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    // M-01: the session this profile is fetched for. If the user signs out or into another account before the
    // answer arrives, it must neither be cached nor returned: it is the previous account's profile.
    final session = SecureStorage.generation;
    try {
      final user = await _remote.getCurrentUser();
      if (session != SecureStorage.generation) {
        return const Left(SessionChangedFailure());
      }
      try {
        // L-14: kept for a cold start without a network (AuthBloc).
        await _storage.saveCachedUser(jsonEncode(user.toJson()));
        // The write above can land after a sign-out cleared storage: take it back.
        if (session != SecureStorage.generation) {
          await _storage.deleteCachedUser();
          return const Left(SessionChangedFailure());
        }
      } catch (_) {}
      return Right(user);
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
    String? currentPassword,
    String? profileImageUrl,
  }) async {
    final session = SecureStorage.generation;
    try {
      final user = await _remote.updateProfile(
        fullName: fullName,
        email: email,
        currentPassword: currentPassword,
        profileImageUrl: profileImageUrl,
      );
      if (session != SecureStorage.generation) {
        return const Left(SessionChangedFailure());
      }
      return Right(user);
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
      // M-05: safe to repeat. The profile POST can commit and a later staff POST fail; a retry used to POST the
      // profile again and be refused as "already exists", leaving the provider stuck. The server is asked what it
      // already has, and only what is missing is sent.
      final me = await _remote.getCurrentUser();
      var profileId = me.providerProfile?.id;
      if (profileId == null || profileId == 0) {
        await _remote.createProviderProfile(profile);
        profileId = (await _remote.getCurrentUser()).providerProfile?.id;
      }
      final have = <String>{
        if (profileId != null && profileId != 0)
          for (final n in await _remote.staffNames(profileId))
            n.trim().toLowerCase(),
      };
      for (final name in staff) {
        final key = name.trim().toLowerCase();
        if (key.isEmpty || !have.add(key)) continue;
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
    } on SessionChangedException {
      return const Left(SessionChangedFailure());
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
