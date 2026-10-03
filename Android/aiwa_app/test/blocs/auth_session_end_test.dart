// CR-18: ending a session ends it on the server too (push address, tokens),
// and a stalled network never keeps the user signed in on the phone.
import 'dart:async';

import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/push/push_registrar.dart';
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

class _Remote implements AuthRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Records the server calls in [calls]; logout never answers when [hang].
class _Api implements ApiClient {
  _Api(this.calls);
  final List<String> calls;
  bool hang = false;
  String? sentRefreshToken;

  @override
  Future<void> logout({String? accessToken, String? refreshToken}) {
    calls.add('logout');
    sentRefreshToken = refreshToken;
    return hang ? Completer<void>().future : Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Push implements PushRegistrar {
  _Push(this.calls);
  final List<String> calls;

  @override
  Future<void> unregister({String? accessToken}) async =>
      calls.add('unregister');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late SecureStorage storage;
  late List<String> calls;
  late _Api api;
  late AuthBloc bloc;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'a',
      AppConstants.refreshTokenKey: 'r',
    });
    storage = SecureStorage(const FlutterSecureStorage());
    calls = [];
    api = _Api(calls);
    final repo = AuthRepositoryImpl(_Remote(), storage);
    bloc = AuthBloc(
      loginUseCase: LoginUseCase(repo),
      registerUseCase: RegisterUseCase(repo),
      sendOtpUseCase: SendOtpUseCase(repo),
      verifyOtpUseCase: VerifyOtpUseCase(repo),
      getCurrentUserUseCase: GetCurrentUserUseCase(repo),
      updateProfileUseCase: UpdateProfileUseCase(repo),
      secureStorage: storage,
      apiClient: api,
      pushRegistrar: _Push(calls),
    );
  });

  tearDown(() => bloc.close());

  Future<AuthState> signedOut() => bloc.stream
      .firstWhere((s) => s is AuthUnauthenticated)
      .timeout(const Duration(seconds: 10));

  test('Remember me off: the cold start unregisters push and revokes the '
      'tokens, then clears them', () async {
    await storage.setRemember(false);
    bloc.add(AuthCheckSessionEvent());
    await signedOut();
    expect(calls, ['unregister', 'logout']);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('Remember me off: a hanging logout does not block clearing', () async {
    await storage.setRemember(false);
    api.hang = true;
    bloc.add(AuthCheckSessionEvent());
    await signedOut();
    expect(calls, contains('logout'));
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('sign-out clears the tokens first; a stalled network never keeps the '
      'user signed in', () async {
    api.hang = true;
    bloc.add(AuthLogoutEvent());
    await signedOut().timeout(const Duration(seconds: 1));
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    // The server still gets the tokens to revoke, read before they were cleared.
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['unregister', 'logout']);
    expect(api.sentRefreshToken, 'r');
  });
}
