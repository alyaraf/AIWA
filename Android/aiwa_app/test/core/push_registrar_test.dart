import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/push/push_registrar.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// FE-3: the device's push token follows the session.
void main() {
  late _Recorder rec;
  late ApiClient api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    rec = _Recorder();
    api = ApiClient(SecureStorage(const FlutterSecureStorage()), adapter: rec);
  });

  test('sign-in registers the token and platform', () async {
    await PushRegistrar(
      api,
      tokenSource: () async => 'tok-1',
      platform: 'ANDROID',
    ).register();
    expect(rec.calls, ['PATCH ${ApiConstants.mePushToken}']);
    expect(rec.bodies.single, {'token': 'tok-1', 'platform': 'ANDROID'});
  });

  test('no token yet (no Firebase) sends nothing', () async {
    await PushRegistrar(api, platform: 'ANDROID').register();
    expect(rec.calls, isEmpty);
  });

  test('sign-out clears the token', () async {
    await PushRegistrar(api, platform: 'IOS').unregister();
    expect(rec.calls, ['DELETE ${ApiConstants.mePushToken}']);
  });

  test('a server error never breaks sign-in or sign-out', () async {
    rec.status = 500;
    final r = PushRegistrar(api, tokenSource: () async => 't', platform: 'IOS');
    await r.register();
    await r.unregister();
    expect(rec.calls, hasLength(2));
  });
}

class _Recorder implements HttpClientAdapter {
  final calls = <String>[];
  final bodies = <Object?>[];
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${o.method} ${o.path}');
    if (o.data != null) {
      bodies.add(o.data is String ? jsonDecode(o.data as String) : o.data);
    }
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
