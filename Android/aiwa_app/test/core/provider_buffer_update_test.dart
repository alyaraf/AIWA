// M-06: changing the travel buffer sends ONLY the buffer, never the (possibly stale) business profile.
import 'dart:typed_data';

import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/provider_dashboard/data/provider_manage_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements HttpClientAdapter {
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    return ResponseBody.fromString('{"data":null}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the buffer stepper PATCHes /provider/mode/travel-buffer with just the minutes', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final rec = _Recorder();
    final repo = ProviderManageRepository(ApiClient(SecureStorage(const FlutterSecureStorage()), adapter: rec));

    final r = await repo.setTravelBuffer(45);

    expect(r.isRight(), isTrue);
    expect(rec.seen, hasLength(1));
    expect(rec.seen.single.method, 'PATCH');
    expect(rec.seen.single.path, ApiConstants.providerTravelBuffer);
    expect(rec.seen.single.queryParameters, {'minutes': 45});
    expect(rec.seen.single.data, isNull); // no business name / bio / address in the request
  });
}
