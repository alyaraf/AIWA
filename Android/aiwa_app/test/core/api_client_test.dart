import 'dart:io';

import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
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
        ..write('{"message":"nope"}')
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

  test('connection refused -> NetworkException', () async {
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      client.get('http://127.0.0.1:$port/200'),
      throwsA(isA<NetworkException>()),
    );
  });
}
