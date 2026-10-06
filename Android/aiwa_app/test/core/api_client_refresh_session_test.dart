// R5-01: a token refresh, a sign-in, a sign-out and a session expiry all change the stored credentials through one
// serialized, session-aware mechanism. The storage double delays individual writes the way a concurrent native
// secure-storage queue can (flutter_secure_storage's iOS plugin dispatches onto a concurrent queue). This is
// host-test evidence of the application's ordering, NOT a reproduction on an iOS device.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds back the write of one specific token value until [release] is completed.
class _DelayedStorage extends SecureStorage {
  _DelayedStorage({this.delayAccess, this.delayRefresh})
    : super(const FlutterSecureStorage());
  final String? delayAccess;
  final String? delayRefresh;
  final started = Completer<void>();
  final release = Completer<void>();

  Future<void> _hold() async {
    if (!started.isCompleted) started.complete();
    await release.future;
  }

  @override
  Future<void> saveAccessToken(String token) async {
    if (token == delayAccess) await _hold();
    await super.saveAccessToken(token);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    if (token == delayRefresh) await _hold();
    await super.saveRefreshToken(token);
  }
}

class _Remote implements AuthRemoteDataSource {
  @override
  Future<Map<String, String>> login({
    required String identifier,
    required String password,
  }) async => {
    'accessToken': 'B-access',
    'refreshToken': 'B-refresh',
    'role': 'CUSTOMER',
    'userId': '2',
  };

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// A's access token is expired (401); the refresh either answers [refreshStatus] (after [refreshGate]) or rotates to
/// A's new pair; a protected call answers with the account its bearer token belongs to.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.refreshStatus = 200, this.refreshGate});
  final int refreshStatus;
  final Future<void>? refreshGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final json = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (options.path == ApiConstants.refresh) {
      await refreshGate;
      final ok = refreshStatus == 200;
      return ResponseBody.fromString(
        jsonEncode(
          ok
              ? {
                  'data': {
                    'accessToken': 'A-rotated',
                    'refreshToken': 'A-refresh-rotated',
                  },
                }
              : {'message': 'rejected'},
        ),
        refreshStatus,
        headers: json,
      );
    }
    final bearer = options.headers['Authorization'];
    if (bearer == 'Bearer A-old') {
      return ResponseBody.fromString('{}', 401, headers: json);
    }
    final account = bearer == 'Bearer B-access'
        ? {'userId': 2, 'account': 'B'}
        : {'userId': 1, 'account': 'A'};
    return ResponseBody.fromString(
      jsonEncode({'data': account}),
      200,
      headers: json,
    );
  }

  @override
  void close({bool force = false}) {}
}

void _accountAIsSignedIn() => FlutterSecureStorage.setMockInitialValues({
  AppConstants.accessTokenKey: 'A-old',
  AppConstants.refreshTokenKey: 'A-refresh',
  AppConstants.userIdKey: '1',
});

Future<Object> _settled(Future<Object?> call) =>
    call.then<Object>((r) => r ?? 'null').catchError((Object e) => e);

Future<void> _expectAccountB(SecureStorage storage, ApiClient client) async {
  expect(await storage.getAccessToken(), 'B-access');
  expect(await storage.getRefreshToken(), 'B-refresh');
  expect(await storage.getUserId(), '2');
  // The next protected request authenticates as B, not as the account whose refresh was delayed.
  final next = await client.get('/audit/protected');
  expect(next.data['data']['userId'], 2);
}

void main() {
  for (final field in ['access', 'refresh']) {
    test(
      'R5-01: account A\'s delayed $field-token write cannot corrupt account B\'s session',
      () async {
        _accountAIsSignedIn();
        final storage = field == 'access'
            ? _DelayedStorage(delayAccess: 'A-rotated')
            : _DelayedStorage(delayRefresh: 'A-refresh-rotated');
        final client = ApiClient(storage, adapter: _Adapter());
        final oldRequest = _settled(client.get('/audit/protected'));
        await storage.started.future.timeout(const Duration(seconds: 3));

        // Account B signs in while A's write is still pending. It queues behind it on the credential lock, so it
        // cannot complete (and be overwritten) before A's stale write lands.
        SecureStorage.beginAuthAttempt();
        final login = AuthRepositoryImpl(
          _Remote(),
          storage,
        ).login(identifier: 'B', password: 'synthetic');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        storage.release.complete();

        expect((await login).isRight(), isTrue);
        await oldRequest;
        await _expectAccountB(storage, client);
      },
    );
  }

  test('R5-01: sign-out while A\'s refresh write is delayed leaves nothing stored', () async {
    _accountAIsSignedIn();
    final storage = _DelayedStorage(delayAccess: 'A-rotated');
    final client = ApiClient(storage, adapter: _Adapter());
    final oldRequest = _settled(client.get('/audit/protected'));
    await storage.started.future.timeout(const Duration(seconds: 3));

    final signedOut = storage.clearAll();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    storage.release.complete();
    await signedOut;
    await oldRequest;

    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
    expect(await storage.getUserId(), isNull);
  });

  test('R5-01: a refresh that finishes after sign-out stores nothing', () async {
    _accountAIsSignedIn();
    final gate = Completer<void>();
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(refreshGate: gate.future));
    final oldRequest = _settled(client.get('/audit/protected'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await storage.clearAll();
    gate.complete();
    await oldRequest;
    await storage.withCredentialLock(() async {}); // let queued credential work drain

    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('R5-01: A\'s rejected refresh after B signed in neither wipes B nor announces a sign-out', () async {
    _accountAIsSignedIn();
    final gate = Completer<void>();
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(
      storage,
      adapter: _Adapter(refreshStatus: 401, refreshGate: gate.future),
    );
    final events = <SessionEvent>[];
    final sub = ApiClient.authEvents.stream.listen(events.add);

    final oldRequest = _settled(client.get('/audit/protected'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    SecureStorage.beginAuthAttempt();
    final login = await AuthRepositoryImpl(
      _Remote(),
      storage,
    ).login(identifier: 'B', password: 'synthetic');
    expect(login.isRight(), isTrue);

    gate.complete(); // A's refresh is rejected only now
    await oldRequest;
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, isEmpty);
    await _expectAccountB(storage, client);
  });

  test('R5-01: the current session\'s rejected refresh still clears it and announces the sign-out', () async {
    _accountAIsSignedIn();
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(refreshStatus: 401));
    final event = ApiClient.authEvents.stream.first;

    await _settled(client.get('/audit/protected'));

    expect((await event.timeout(const Duration(seconds: 3))).status, 401);
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('R5-01: storeRefreshedTokens and clearIfSession re-check the session inside the lock', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorage(const FlutterSecureStorage());
    final stale = SecureStorage.generation;
    storage.markNewSession(); // another account signed in

    expect(
      await storage.storeRefreshedTokens(
        session: stale,
        accessToken: 'x',
        refreshToken: 'y',
      ),
      isFalse,
    );
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.clearIfSession(stale), isFalse);

    await storage.saveAccessToken('kept');
    expect(await storage.clearIfSession(stale), isFalse);
    expect(await storage.getAccessToken(), 'kept');

    final current = SecureStorage.generation;
    expect(
      await storage.storeRefreshedTokens(
        session: current,
        accessToken: 'a2',
        refreshToken: 'r2',
      ),
      isTrue,
    );
    expect(await storage.getAccessToken(), 'a2');
    expect(await storage.getRefreshToken(), 'r2');
    expect(await storage.clearIfSession(current), isTrue);
    expect(await storage.getAccessToken(), isNull);
  });
}
