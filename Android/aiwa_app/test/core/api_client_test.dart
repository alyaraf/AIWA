import 'dart:io';
import 'dart:typed_data';

import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositories catch ServerException / UnauthorizedException /
/// NetworkException, so ApiClient must throw those, not DioException.
void main() {
  late HttpServer server;
  late ApiClient client;
  late String base;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    client = ApiClient(SecureStorage(const FlutterSecureStorage()));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) {
      req.response
        ..statusCode = int.parse(req.uri.pathSegments.last)
        ..headers.contentType = ContentType.json
        ..write(
          req.uri.queryParameters['code'] == null
              ? '{"message":"nope"}'
              : '{"message":"nope","code":"${req.uri.queryParameters['code']}"}',
        )
        ..close();
    });
  });

  tearDownAll(() => server.close(force: true));

  test('401 without a refresh token -> UnauthorizedException', () {
    expect(client.get('$base/401'), throwsA(isA<UnauthorizedException>()));
  });

  test('404 -> ServerException with status and backend message', () async {
    await expectLater(
      client.get('$base/404'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
  });

  test('423 -> ServerException and an auth event', () async {
    final event = ApiClient.authEvents.stream.first;
    await expectLater(client.get('$base/423'), throwsA(isA<ServerException>()));
    expect(await event, 423);
  });

  test('a role 403 opens the Forbidden screen (auth event)', () async {
    final event = ApiClient.authEvents.stream.first;
    await expectLater(
      client.get('$base/403?code=${ApiClient.roleForbiddenCode}'),
      throwsA(isA<ServerException>()),
    );
    expect(await event, 403);
  });

  test('a business 403 is only an error for the screen, no auth event', () async {
    final events = <int>[];
    final sub = ApiClient.authEvents.stream.listen(events.add);
    await expectLater(
      client.get('$base/403?code=error.access_denied'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isEmpty);
  });

  test('connection refused -> NetworkException', () async {
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      client.get('http://127.0.0.1:$port/200'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('parallel 401s share one refresh and all retry', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
    final adapter = _RefreshAdapter();
    final c = ApiClient(
      SecureStorage(const FlutterSecureStorage()),
      adapter: adapter,
    );
    final codes = await Future.wait(
      List.generate(3, (i) => c.get('/me/$i').then((r) => r.statusCode)),
    );
    expect(codes, [200, 200, 200]);
    expect(adapter.refreshes, 1);
  });

  test('the rotated refresh token replaces the spent one', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
    final storage = SecureStorage(const FlutterSecureStorage());
    final c = ApiClient(storage, adapter: _RefreshAdapter());
    expect((await c.get('/me')).statusCode, 200);
    expect(await storage.getAccessToken(), 'new');
    // The backend blacklists 'r' on use; keeping it would sign the user
    // out at the next refresh.
    expect(await storage.getRefreshToken(), 'r2');
  });

  test('signing out while a refresh is in flight does not sign back in (DR-003)', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
    final storage = SecureStorage(const FlutterSecureStorage());
    final c = ApiClient(storage, adapter: _RefreshAdapter());
    final call = c.get('/me');
    // The refresh takes 50 ms; the user signs out meanwhile.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await storage.clearAll();
    await expectLater(call, throwsA(isA<UnauthorizedException>()));
    expect(await storage.getAccessToken(), isNull);
    expect(await storage.getRefreshToken(), isNull);
  });

  test('a refresh finishing after sign-out does not write the rotated token (CR-18)', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
    final storage = _SignOutAfterAccessWrite();
    final c = ApiClient(storage, adapter: _RefreshAdapter());
    await expectLater(c.get('/me'), throwsA(isA<UnauthorizedException>()));
    // 'r2' would keep the signed-out user's session alive on this phone.
    expect(await storage.getRefreshToken(), isNull);
    expect(await storage.getAccessToken(), isNull);
  });

  test('a 5xx on refresh keeps the tokens (FE-32)', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
    final storage = SecureStorage(const FlutterSecureStorage());
    final c = ApiClient(storage, adapter: _RefreshAdapter(refreshStatus: 503));
    await expectLater(c.get('/me'), throwsA(isA<UnauthorizedException>()));
    expect(await storage.getRefreshToken(), 'r');
  });
}

/// The user signs out the moment the refreshed access token is stored, i.e.
/// between the two token writes of a refresh.
class _SignOutAfterAccessWrite extends SecureStorage {
  _SignOutAfterAccessWrite() : super(const FlutterSecureStorage());

  @override
  Future<void> saveAccessToken(String token) async {
    await super.saveAccessToken(token);
    await clearAll();
  }
}

/// 401 unless the request carries the refreshed token; refresh is slow so
/// all three requests fail while it is in flight.
class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({this.refreshStatus = 200});
  final int refreshStatus;
  int refreshes = 0;
  static final _json = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (o.path == ApiConstants.refresh) {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (refreshStatus != 200) {
        return ResponseBody.fromString('{}', refreshStatus, headers: _json);
      }
      return ResponseBody.fromString(
        '{"data":{"accessToken":"new","refreshToken":"r2"}}',
        200,
        headers: _json,
      );
    }
    final ok = o.headers['Authorization'] == 'Bearer new';
    return ResponseBody.fromString('{}', ok ? 200 : 401, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}
