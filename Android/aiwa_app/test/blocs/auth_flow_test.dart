import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/register_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:aiwa_app/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login throws [loginError]; records reset-password calls.
class _Remote implements AuthRemoteDataSource {
  Object loginError = const UnauthorizedException();
  final resets = <String>[];

  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async => throw loginError;

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async => resets.add('$phone/$code');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  FlutterSecureStorage.setMockInitialValues({});
  final storage = SecureStorage(const FlutterSecureStorage());
  late _Remote remote;
  late AuthRepositoryImpl repo;

  setUp(() {
    remote = _Remote();
    repo = AuthRepositoryImpl(remote, storage);
  });

  test('wrong password maps to the prototype copy', () async {
    final r = await repo.login(identifier: '+20100', password: 'wrong');
    expect(
      r.fold((f) => f.message, (_) => null),
      "That phone/email and password don't match.",
    );
  });

  test('reset sends phone + code once; email is not supported yet', () async {
    await repo.resetPassword(
      identifier: '+20100',
      code: '123456',
      newPassword: 'secret',
    );
    expect(remote.resets, ['+20100/123456']);

    final r = await repo.resetPassword(
      identifier: 'a@b.co',
      code: '1',
      newPassword: 'secret',
    );
    expect(r.fold((f) => f, (_) => null), emailOtpUnsupported);
    expect(remote.resets, hasLength(1));
  });

  test(
    'an unexpected throw ends in AuthError, not a stuck AuthLoading',
    () async {
      remote.loginError = StateError('mfa response has no tokens');
      final bloc = AuthBloc(
        loginUseCase: LoginUseCase(repo),
        registerUseCase: RegisterUseCase(repo),
        sendOtpUseCase: SendOtpUseCase(repo),
        verifyOtpUseCase: VerifyOtpUseCase(repo),
        getCurrentUserUseCase: GetCurrentUserUseCase(repo),
        updateProfileUseCase: UpdateProfileUseCase(repo),
        secureStorage: storage,
      );
      bloc.add(const AuthLoginEvent(identifier: 'x', password: 'secret'));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<AuthLoading>(), isA<AuthError>()]),
      );
      await bloc.close();
    },
  );

  test('Remember me off ends the session at the next cold start', () async {
    await storage.saveAccessToken('t');
    await storage.setRemember(false);
    final bloc = AuthBloc(
      loginUseCase: LoginUseCase(repo),
      registerUseCase: RegisterUseCase(repo),
      sendOtpUseCase: SendOtpUseCase(repo),
      verifyOtpUseCase: VerifyOtpUseCase(repo),
      getCurrentUserUseCase: GetCurrentUserUseCase(repo),
      updateProfileUseCase: UpdateProfileUseCase(repo),
      secureStorage: storage,
    );
    bloc.add(AuthCheckSessionEvent());
    await expectLater(bloc.stream, emits(isA<AuthUnauthenticated>()));
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRemember(), isTrue);
    await bloc.close();
  });
}
