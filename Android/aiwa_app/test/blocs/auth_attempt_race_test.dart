// R4-05: an obsolete authentication operation (overtaken by a newer sign-in / registration / sign-out) must neither
// clear or overwrite the newer credentials nor publish its outcome, whatever that outcome is (success, failure, a
// SessionChangedFailure, or an unexpected exception).
import 'dart:async';

import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _tokens(String who, String id) => {
  'accessToken': who,
  'refreshToken': '$who-refresh',
  'role': 'CUSTOMER',
  'userId': id,
};

class _Remote implements AuthRemoteDataSource {
  /// Login "A" is answered by the test; anything else answers at once with B's tokens.
  final a = Completer<Map<String, String>>();
  final otp = Completer<void>();
  final registerA = Completer<Map<String, String>>();

  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async {
    if (identifier == 'A') return a.future;
    return _tokens('B', '2');
  }

  @override
  Future<Map<String, String>> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required String role,
    String? gender,
    String? profileImageUrl,
    String? preferredLanguage,
  }) async {
    if (fullName == 'A') return registerA.future;
    return _tokens('B', '2');
  }

  @override
  Future<void> sendOtp({required String phone}) => otp.future;

  @override
  Future<UserModel> getCurrentUser() async => UserModel.fromJson({
    'id': 2,
    'fullName': 'Bob',
    'role': 'CUSTOMER',
    'email': 'bob@example.test',
  });

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SlowRemember extends SecureStorage {
  final remember = Completer<bool>();
  _SlowRemember() : super(const FlutterSecureStorage());
  @override
  Future<bool> getRemember() => remember.future;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late List<Map<String, String?>> revoked;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    revoked = [];
  });

  AuthRepositoryImpl repo(_Remote remote, SecureStorage storage) =>
      AuthRepositoryImpl(
        remote,
        storage,
        revokeTokens: ({accessToken, refreshToken}) async =>
            revoked.add({'access': accessToken, 'refresh': refreshToken}),
      );

  Future<AuthBloc> signedInAsBAfterStartingA(
    _Remote remote,
    SecureStorage storage,
  ) async {
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthLoginEvent(identifier: 'A', password: 'x', remember: true));
    await _settle();
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    return bloc;
  }

  test('an obsolete login that fails with SessionChanged leaves B signed in',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = await signedInAsBAfterStartingA(remote, storage);
    remote.a.completeError(const SessionChangedException());
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    await bloc.close();
  });

  test('an obsolete login that fails with an ordinary error shows nothing',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = await signedInAsBAfterStartingA(remote, storage);
    remote.a.completeError(ServerException(message: 'wrong password'));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    await bloc.close();
  });

  test('an obsolete login that SUCCEEDS stores nothing, and its server session is revoked',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = await signedInAsBAfterStartingA(remote, storage);
    remote.a.complete(_tokens('A', '1'));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    expect(await storage.getRefreshToken(), 'B-refresh');
    expect(await storage.getUserId(), '2');
    expect(revoked, [
      {'access': 'A', 'refresh': 'A-refresh'},
    ]);
    await bloc.close();
  });

  test('an obsolete login that throws an unexpected exception does not replace B\'s state',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = await signedInAsBAfterStartingA(remote, storage);
    remote.a.completeError(StateError('bad payload'));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    await bloc.close();
  });

  test('the CURRENT login still reports its own failure and its own unexpected exception',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthLoginEvent(identifier: 'A', password: 'x', remember: true));
    await _settle();
    remote.a.completeError(ServerException(message: 'wrong password'));
    await _settle();
    expect(bloc.state, isA<AuthError>());
    expect((bloc.state as AuthError).message, 'wrong password');
    await bloc.close();
  });

  test('a SessionChanged answer to the current login is not shown as an error',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthLoginEvent(identifier: 'A', password: 'x', remember: true));
    await _settle();
    remote.a.completeError(const SessionChangedException());
    await _settle();
    expect(bloc.state, isNot(isA<AuthError>()));
    await bloc.close();
  });

  test('an obsolete cold-start check with "remember me" off does not delete B\'s tokens',
      () async {
    final remote = _Remote();
    final storage = _SlowRemember();
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthCheckSessionEvent());
    await _settle();
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    storage.remember.complete(false);
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    expect(revoked, isEmpty, reason: 'B\'s tokens are not the cold-start session to revoke');
    await bloc.close();
  });

  test('a cold-start check that is still current ends a non-remembered session',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'old',
      'refresh_token': 'old-refresh',
    });
    final remote = _Remote();
    final storage = _SlowRemember();
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthCheckSessionEvent());
    await _settle();
    storage.remember.complete(false);
    await _settle();
    expect(bloc.state, isA<AuthUnauthenticated>());
    expect(await storage.hasValidSession(), isFalse);
    await bloc.close();
  });

  test('a sign-out that is overtaken by a sign-in does not wipe the new credentials',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    // sign-out and, immediately, another sign-in in the same turn: the sign-in began last and owns the credentials
    bloc.add(AuthLogoutEvent());
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    await bloc.close();
  });

  test('an OTP answer that arrives after a sign-in does not replace the signed-in state',
      () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthSendOtpEvent(phone: '+201000000000'));
    await _settle();
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    remote.otp.complete();
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    await bloc.close();
  });

  test('an obsolete registration stores nothing and publishes nothing', () async {
    final remote = _Remote();
    final storage = SecureStorage(const FlutterSecureStorage());
    final bloc = AuthBloc(
      authRepository: repo(remote, storage),
      secureStorage: storage,
    );
    bloc.add(AuthRegisterEvent(fullName: 'A', password: 'x', role: 'CUSTOMER', phone: '+20100'));
    await _settle();
    bloc.add(AuthLoginEvent(identifier: 'B', password: 'x', remember: true));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    remote.registerA.complete(_tokens('A', '1'));
    await _settle();
    expect(bloc.state, isA<AuthAuthenticated>());
    expect(await storage.getAccessToken(), 'B');
    expect(revoked.single['access'], 'A');
    await bloc.close();
  });

  test('credential writes of two operations never interleave', () async {
    final storage = SecureStorage(const FlutterSecureStorage());
    final order = <String>[];
    final first = storage.withCredentialLock(() async {
      order.add('first start');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      order.add('first end');
    });
    final second = storage.withCredentialLock(() async {
      order.add('second start');
    });
    await Future.wait([first, second]);
    expect(order, ['first start', 'first end', 'second start']);
  });
}
