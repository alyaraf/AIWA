// R6-02: a failed answer (423 account locked, role 403) and the global auth event it produces belong to the session that
// SENT the request. These tests use the real ApiClient, AuthRepositoryImpl, SecureStorage and AuthBloc, and the real
// routing of the app's global event handler (routeSessionEvent, which _ThemedAppState delegates to); only the network
// and the native secure-storage plugin are doubles. They run on the host, not on a device.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/app.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/router/app_router.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:aiwa_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signs in accounts A and B; B's sign-in can be held back to model "a sign-in in progress".
class _Remote implements AuthRemoteDataSource {
  Completer<void>? bGate;
  String _who = 'A';

  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async {
    _who = identifier;
    if (identifier == 'B') await bGate?.future;
    final b = identifier == 'B';
    return {
      'accessToken': b ? 'B-access' : 'A-access',
      'refreshToken': b ? 'B-refresh' : 'A-refresh',
      'role': 'CUSTOMER',
      'userId': b ? '2' : '1',
    };
  }

  @override
  Future<UserModel> getCurrentUser() async => UserModel.fromJson({
    'id': _who == 'B' ? 2 : 1,
    'fullName': _who == 'B' ? 'Bob' : 'Alice',
    'role': 'CUSTOMER',
  });

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Every request waits for [release], then answers [status] (with [code] in the body).
class _SlowAdapter implements HttpClientAdapter {
  _SlowAdapter(this.status, {this.code});
  final int status;
  final String? code;
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return ResponseBody.fromString(
      jsonEncode({'message': 'refused', if (code != null) 'code': code}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Holds the token reads back once [hold] is set, like a slow native secure-storage queue.
class _SlowReadStorage extends SecureStorage {
  _SlowReadStorage() : super(const FlutterSecureStorage());
  Completer<void>? hold;
  final reading = Completer<void>();

  @override
  Future<String?> getAccessToken() async {
    final gate = hold;
    if (gate != null) {
      if (!reading.isCompleted) reading.complete();
      await gate.future;
    }
    return super.getAccessToken();
  }
}

class _Nav {
  final went = <String>[];
  final pushed = <String>[];
  String path = '/home';
}

class _Rig {
  _Rig(this.remote, this.storage, this.bloc, this.nav, this.sub);
  final _Remote remote;
  final SecureStorage storage;
  final AuthBloc bloc;
  final _Nav nav;
  final StreamSubscription<SessionEvent> sub;

  /// The delayed protected request of the session that is current NOW; its failure is returned, not thrown.
  Future<(_SlowAdapter, Future<Object>)> startRequest(int status, {String? code}) async {
    final adapter = _SlowAdapter(status, code: code);
    final client = ApiClient(storage, adapter: adapter);
    final result = client.get('/protected').then<Object>((r) => r).catchError((Object e) => e);
    await adapter.started.future.timeout(const Duration(seconds: 3));
    return (adapter, result);
  }

  Future<void> signIn(String who) async {
    final authenticated = bloc.stream.firstWhere((s) => s is AuthAuthenticated);
    bloc.add(AuthLoginEvent(identifier: who, password: 'synthetic'));
    await authenticated.timeout(const Duration(seconds: 3));
  }

  Future<void> expectAccountB() async {
    final state = bloc.state;
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.id, 2);
    expect(await storage.getAccessToken(), 'B-access');
    expect(await storage.getRefreshToken(), 'B-refresh');
    expect(await storage.getUserId(), '2');
    expect(nav.went, isEmpty, reason: 'B must not be redirected');
    expect(nav.pushed, isEmpty, reason: 'B must not be sent to Forbidden');
  }
}

Future<_Rig> _rig({SecureStorage? withStorage}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final storage = withStorage ?? SecureStorage(const FlutterSecureStorage());
  final remote = _Remote();
  final bloc = AuthBloc(authRepository: AuthRepositoryImpl(remote, storage), secureStorage: storage);
  final nav = _Nav();
  // The same subscription _ThemedAppState makes, with the router replaced by a recorder.
  final sub = ApiClient.authEvents.stream.listen(
    (event) => routeSessionEvent(
      event,
      bloc: bloc,
      currentPath: () => nav.path,
      go: (route) {
        nav.went.add(route);
        nav.path = route;
      },
      push: nav.pushed.add,
    ),
  );
  final rig = _Rig(remote, storage, bloc, nav, sub);
  await rig.signIn('A'); // account A is signed in
  return rig;
}

Future<void> _drain() async {
  for (var i = 0; i < 5; i++) {
    await pumpEventQueue();
  }
}

void main() {
  late _Rig rig;
  tearDown(() async {
    await rig.sub.cancel();
    await rig.bloc.close();
  });

  test('a delayed A 423 after B signed in neither logs B out nor opens Account locked', () async {
    rig = await _rig();
    final (adapter, old) = await rig.startRequest(423);
    await rig.signIn('B');
    adapter.release.complete();
    final outcome = await old;
    await _drain();

    expect(outcome, isA<SessionChangedException>(), reason: 'the stale caller must not see a lock error');
    await rig.expectAccountB();
  });

  test('a delayed A role-forbidden 403 after B signed in does not open Forbidden for B', () async {
    rig = await _rig();
    final (adapter, old) = await rig.startRequest(403, code: ApiClient.roleForbiddenCode);
    await rig.signIn('B');
    adapter.release.complete();
    expect(await old, isA<SessionChangedException>());
    await _drain();

    await rig.expectAccountB();
  });

  test('a delayed A 423 while B is still signing in (nothing stored yet) is dropped too', () async {
    rig = await _rig();
    rig.remote.bGate = Completer<void>();
    final (adapter, old) = await rig.startRequest(423);

    final authenticated = rig.bloc.stream.firstWhere((s) => s is AuthAuthenticated && s.user.id == 2);
    rig.bloc.add(AuthLoginEvent(identifier: 'B', password: 'synthetic')); // waiting for the server
    await _drain();
    expect(await rig.storage.getAccessToken(), 'A-access', reason: 'B has stored nothing yet');

    adapter.release.complete(); // A's 423 lands in the middle of B's sign-in
    expect(await old, isA<SessionChangedException>());
    await _drain();
    expect(await rig.storage.getAccessToken(), 'A-access', reason: 'A\'s lock must not wipe credentials');

    rig.remote.bGate!.complete();
    await authenticated.timeout(const Duration(seconds: 3));
    await rig.expectAccountB();
  });

  test('an event queued before the account change is dropped when it is delivered', () async {
    rig = await _rig();
    final ownerA = SecureStorage.currentOwner;
    ApiClient.authEvents.add(SessionEvent(423, ownerA));
    rig.storage.markNewSession(); // B takes over before the stream delivers the event
    rig.remote._who = 'B';
    await rig.storage.saveAccessToken('B-access');
    await rig.storage.saveRefreshToken('B-refresh');
    await rig.storage.saveUserId('2');
    await _drain();

    expect(rig.nav.went, isEmpty);
    expect(await rig.storage.getAccessToken(), 'B-access');
    expect(await rig.storage.getRefreshToken(), 'B-refresh');
    expect(rig.bloc.state, isA<AuthAuthenticated>());
  });

  test('the same for a queued 401 and a queued 403', () async {
    rig = await _rig();
    final ownerA = SecureStorage.currentOwner;
    ApiClient.authEvents.add(SessionEvent(401, ownerA));
    ApiClient.authEvents.add(SessionEvent(403, ownerA));
    SecureStorage.beginAuthAttempt(); // a sign-in began before delivery
    await _drain();

    expect(rig.nav.went, isEmpty);
    expect(rig.nav.pushed, isEmpty);
    expect(rig.bloc.state, isA<AuthAuthenticated>());
    expect(await rig.storage.getAccessToken(), 'A-access');
  });

  test('the sign-out itself is ownership-checked: a logout of A queued behind B\'s sign-in is dropped', () async {
    rig = await _rig();
    final logout = AuthLogoutEvent(owner: SecureStorage.currentOwner);
    rig.bloc.add(logout);
    SecureStorage.beginAuthAttempt(); // B's sign-in begins before the bloc handles the queued sign-out
    expect(await logout.applied.timeout(const Duration(seconds: 3)), isFalse);

    expect(rig.bloc.state, isA<AuthAuthenticated>());
    expect(await rig.storage.getAccessToken(), 'A-access');
    expect(await rig.storage.getRefreshToken(), 'A-refresh');
  });

  test('a sign-out for A that was valid when sent but is overtaken while it reads the tokens signs nobody out', () async {
    final storage = _SlowReadStorage();
    rig = await _rig(withStorage: storage);
    storage.hold = Completer<void>();
    final logout = AuthLogoutEvent(owner: SecureStorage.currentOwner);
    rig.bloc.add(logout);
    await storage.reading.future.timeout(const Duration(seconds: 3)); // it passed the ownership check, is reading
    SecureStorage.beginAuthAttempt(); // B's sign-in begins meanwhile
    storage.hold!.complete();
    expect(await logout.applied.timeout(const Duration(seconds: 3)), isFalse);

    expect(await rig.storage.getAccessToken(), 'A-access', reason: 'an overtaken sign-out wipes nothing');
  });

  test('current session: a 423 still signs the account out and opens Account locked', () async {
    rig = await _rig();
    final (adapter, old) = await rig.startRequest(423);
    adapter.release.complete();
    expect(await old, isA<ServerException>().having((e) => e.statusCode, 'statusCode', 423));
    await _drain();

    expect(rig.nav.went, [AppRoutes.accountLocked]);
    expect(rig.bloc.state, isA<AuthUnauthenticated>());
    expect(await rig.storage.getAccessToken(), isNull);
    expect(await rig.storage.getRefreshToken(), isNull);
  });

  test('current session: a role 403 still opens Forbidden and keeps the user signed in', () async {
    rig = await _rig();
    final (adapter, old) = await rig.startRequest(403, code: ApiClient.roleForbiddenCode);
    adapter.release.complete();
    expect(await old, isA<ServerException>().having((e) => e.statusCode, 'statusCode', 403));
    await _drain();

    expect(rig.nav.pushed, [AppRoutes.forbidden]);
    expect(rig.nav.went, isEmpty);
    expect(rig.bloc.state, isA<AuthAuthenticated>());
    expect(await rig.storage.getAccessToken(), 'A-access');
  });

  test('current session: the refresh-rejected 401 event still signs out and opens Session expired', () async {
    rig = await _rig();
    // A's refresh was rejected: the storage ended session A, and the event names the signed-out state.
    final ended = SecureStorage.generation;
    expect(await rig.storage.clearIfSession(ended), isTrue);
    ApiClient.authEvents.add(SessionEvent(401, SecureStorage.currentOwner));
    await _drain();

    expect(rig.nav.went, [AppRoutes.sessionExpired]);
    expect(rig.bloc.state, isA<AuthUnauthenticated>());
  });

  test('a late A 423 after A signed out (no new account yet) is dropped as well', () async {
    rig = await _rig();
    final (adapter, old) = await rig.startRequest(423);
    final out = rig.bloc.stream.firstWhere((s) => s is AuthUnauthenticated);
    rig.bloc.add(AuthLogoutEvent());
    await out.timeout(const Duration(seconds: 3));
    adapter.release.complete();
    expect(await old, isA<SessionChangedException>());
    await _drain();

    expect(rig.nav.went, isEmpty, reason: 'no Account locked screen for a session that already ended');
  });

  test('the owner of the app\'s own sign-in 423 is the current one: a locked account at login still routes', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorage(const FlutterSecureStorage());
    final adapter = _SlowAdapter(423)..release.complete();
    final client = ApiClient(storage, adapter: adapter);
    final events = <SessionEvent>[];
    final sub = ApiClient.authEvents.stream.listen(events.add);
    SecureStorage.beginAuthAttempt(); // what AuthBloc does when a sign-in starts
    await client.get('/login').then<Object>((r) => r).catchError((Object e) => e);
    await _drain();
    await sub.cancel();

    expect(events.map((e) => e.status), [423]);
    expect(SecureStorage.owns(events.single.owner), isTrue);
    rig = await _rig(); // only for tearDown
  });
}
