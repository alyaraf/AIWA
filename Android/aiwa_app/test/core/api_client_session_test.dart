// M-01 (transport half) and M-03: the API client drops answers that belong to an ended session, and a multipart
// upload survives the 401 -> refresh -> retry path.
import 'dart:async';
import 'dart:convert';
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

final _json = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Answers every GET after [delay]; an upload is answered 401 unless it carries the refreshed token. Records the
/// bytes of each upload body that reached it.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.delay = Duration.zero});
  final Duration delay;
  final List<String> uploads = [];
  final List<String?> uploadAuth = [];
  int refreshes = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (o.path == ApiConstants.refresh) {
      refreshes++;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'accessToken': 'fresh', 'refreshToken': 'r2'},
        }),
        200,
        headers: _json,
      );
    }
    if (o.method == 'POST' && requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      uploads.add(utf8.decode(bytes, allowMalformed: true));
      uploadAuth.add(o.headers['Authorization'] as String?);
      if (o.headers['Authorization'] != 'Bearer fresh') {
        return ResponseBody.fromString('{"message":"expired"}', 401, headers: _json);
      }
      return ResponseBody.fromString('{"data":{"url":"/files/x.jpg"}}', 200, headers: _json);
    }
    await Future<void>.delayed(delay);
    return ResponseBody.fromString('{"data":{"fullName":"alice"}}', 200, headers: _json);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'old',
      AppConstants.refreshTokenKey: 'r',
    });
  });

  test("M-01: a successful answer that arrives after the user signed out is dropped", () async {
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(delay: const Duration(milliseconds: 60)));

    final call = client.get('/auth/me');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await storage.clearAll(); // sign-out while the request is in flight

    await expectLater(call, throwsA(isA<SessionChangedException>()));
  });

  test("M-01: the same when another account signs in meanwhile", () async {
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(delay: const Duration(milliseconds: 60)));

    final call = client.get('/auth/me');
    await Future<void>.delayed(const Duration(milliseconds: 15));
    storage.markNewSession(); // account B signs in

    await expectLater(call, throwsA(isA<SessionChangedException>()));
  });

  test('M-01: dropping the answer is not an outage (no offline banner)', () async {
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(delay: const Duration(milliseconds: 40)));
    final seen = <bool>[];
    final sub = ApiClient.offline.stream.listen(seen.add);

    final call = client.get('/auth/me');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await storage.clearAll();
    await expectLater(call, throwsA(isA<SessionChangedException>()));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, isNot(contains(true)));
  });

  test('an answer for the CURRENT session is delivered as before', () async {
    final storage = SecureStorage(const FlutterSecureStorage());
    final client = ApiClient(storage, adapter: _Adapter(delay: const Duration(milliseconds: 20)));
    final r = await client.get('/auth/me');
    expect(r.statusCode, 200);
  });

  test('M-03: a multipart upload that hits an expired token is replayed with a readable body', () async {
    final dir = await Directory.systemTemp.createTemp('upload');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/avatar.jpg')..writeAsStringSync('JPEG-BYTES-123');
    final storage = SecureStorage(const FlutterSecureStorage());
    final adapter = _Adapter();
    final client = ApiClient(storage, adapter: adapter);

    final r = await client.postForm(
      '/users/me/avatar',
      formData: FormData.fromMap({'image': await MultipartFile.fromFile(file.path)}),
    );

    expect(r.statusCode, 200);
    expect(adapter.refreshes, 1);
    expect(adapter.uploads, hasLength(2)); // first rejected with 401, then replayed
    expect(adapter.uploadAuth, ['Bearer old', 'Bearer fresh']);
    for (final body in adapter.uploads) {
      expect(body, contains('JPEG-BYTES-123')); // the replay carries the whole file, not an empty/failed body
      expect(body, contains('name="image"'));
    }
  });
}
