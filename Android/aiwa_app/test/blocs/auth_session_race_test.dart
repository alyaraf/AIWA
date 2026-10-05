// M-01 / M-04: an answer for an earlier session must never restore that identity, and a transient profile error
// must not turn a signed-in user into a guest.
import 'dart:async';
import 'dart:convert';

import 'package:aiwa_app/core/constants/app_constants.dart';
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

UserModel _user(int id, String name) => UserModel.fromJson({
  'id': id,
  'fullName': name,
  'role': 'CUSTOMER',
  'email': '$name@example.test',
});

/// Profile answers are handed out by the test through [profiles]: each call to getCurrentUser takes the next
/// Completer, so the test decides the order in which they finish.
class _Remote implements AuthRemoteDataSource {
  final List<Completer<UserModel>> profiles = [];
  int profileCalls = 0;
  Map<String, String> nextLogin = {
    'accessToken': 'tokenB',
    'refreshToken': 'refreshB',
    'role': 'CUSTOMER',
    'userId': '2',
  };

  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async => nextLogin;

  @override
  Future<UserModel> getCurrentUser() {
    final c = profiles[profileCalls++];
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late SecureStorage storage;
  late _Remote remote;
  late AuthBloc bloc;
  late List<AuthState> states;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'tokenA',
      AppConstants.refreshTokenKey: 'refreshA',
    });
    storage = SecureStorage(const FlutterSecureStorage());
    remote = _Remote();
    bloc = AuthBloc(
      authRepository: AuthRepositoryImpl(remote, storage),
      secureStorage: storage,
    );
    states = [];
    bloc.stream.listen(states.add);
  });

  tearDown(() => bloc.close());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('M-01: a profile that finishes after sign-out neither authenticates '
      'nor is cached', () async {
    final a = Completer<UserModel>();
    remote.profiles.add(a);
    bloc.add(AuthGetCurrentUserEvent()); // account A's profile is requested...
    await settle();
    bloc.add(AuthLogoutEvent()); // ...then A signs out
    await settle();
    expect(states.last, isA<AuthUnauthenticated>());

    a.complete(_user(1, 'alice')); // ...and the old answer finally arrives
    await settle();

    expect(states.whereType<AuthAuthenticated>(), isEmpty);
    expect(states.last, isA<AuthUnauthenticated>());
    expect(await storage.getCachedUser(), isNull);
  });

  test("M-01: account A's late profile does not replace account B's identity "
      'or cache', () async {
    final a = Completer<UserModel>();
    final b = Completer<UserModel>();
    remote.profiles.addAll([a, b]);
    bloc.add(AuthGetCurrentUserEvent()); // A's profile in flight
    await settle();
    bloc.add(AuthLogoutEvent());
    await settle();

    bloc.add(AuthLoginEvent(identifier: 'bob@example.test', password: 'x', remember: true));
    await settle();
    b.complete(_user(2, 'bob'));
    await settle();
    expect(states.last, isA<AuthAuthenticated>());
    expect((states.last as AuthAuthenticated).user.fullName, 'bob');

    a.complete(_user(1, 'alice')); // A answers last
    await settle();

    expect((states.last as AuthAuthenticated).user.fullName, 'bob');
    expect(
      states.whereType<AuthAuthenticated>().map((s) => s.user.fullName),
      isNot(contains('alice')),
    );
    final cached = jsonDecode((await storage.getCachedUser())!) as Map;
    expect(cached['fullName'], 'bob');
  });

  test("M-01: a cold-start profile finishing after a sign-out is dropped", () async {
    final a = Completer<UserModel>();
    remote.profiles.add(a);
    bloc.add(AuthCheckSessionEvent());
    await settle();
    bloc.add(AuthLogoutEvent());
    await settle();

    a.complete(_user(1, 'alice'));
    await settle();

    expect(states.whereType<AuthAuthenticated>(), isEmpty);
    expect(states.last, isA<AuthUnauthenticated>());
  });

  test('M-04: a transient failure keeps the identity and reports the error', () async {
    final first = Completer<UserModel>();
    final second = Completer<UserModel>();
    final third = Completer<UserModel>();
    remote.profiles.addAll([first, second, third]);
    bloc.add(AuthGetCurrentUserEvent());
    first.complete(_user(1, 'alice'));
    await settle();
    expect((states.last as AuthAuthenticated).refreshError, isNull);

    bloc.add(AuthGetCurrentUserEvent());
    await settle();
    second.completeError(const NetworkException());
    await settle();
    final failed = states.last as AuthAuthenticated; // still signed in
    expect(failed.user.fullName, 'alice');
    expect(failed.refreshError, isNotNull);
    expect(states.whereType<AuthError>(), isEmpty);

    bloc.add(AuthGetCurrentUserEvent()); // the retry works
    third.complete(_user(1, 'alice'));
    await settle();
    expect((states.last as AuthAuthenticated).refreshError, isNull);
  });

  test('M-04: a rejected session (401) is the only failure that signs out', () async {
    final first = Completer<UserModel>();
    final second = Completer<UserModel>();
    remote.profiles.addAll([first, second]);
    bloc.add(AuthGetCurrentUserEvent());
    first.complete(_user(1, 'alice'));
    await settle();
    bloc.add(AuthGetCurrentUserEvent());
    await settle();
    second.completeError(const UnauthorizedException());
    await settle();
    expect(states.last, isA<AuthUnauthenticated>());
  });

  test('M-04: a server error at cold start opens the cached account instead of '
      'the sign-in screen', () async {
    await storage.saveCachedUser(jsonEncode(_user(1, 'alice').toJson()));
    final c = Completer<UserModel>();
    remote.profiles.add(c);
    bloc.add(AuthCheckSessionEvent());
    await settle(); // the profile request is now in flight
    c.completeError(const ServerException(message: 'boom', statusCode: 500));
    await settle();
    final s = states.last as AuthAuthenticated;
    expect(s.user.fullName, 'alice');
    expect(s.refreshError, isNotNull);
  });
}
