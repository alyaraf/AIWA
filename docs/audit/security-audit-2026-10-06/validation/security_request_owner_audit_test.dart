import 'dart:async';
import 'dart:typed_data';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// Host model of an asynchronous secure-storage read serviced after another credential operation.
class _HeldRead extends SecureStorage {
  _HeldRead() : super(const FlutterSecureStorage());
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> getAccessToken() async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.getAccessToken();
  }
}

class _RecordAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add(options);
    return ResponseBody.fromString('{"data":{"fullName":"A edit"}}', 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  test('audit: A mutation is transmitted with B bearer after ownership changes during token lookup', () async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'A-access',
      AppConstants.refreshTokenKey: 'A-refresh',
    });
    final storage = _HeldRead();
    storage.markNewSession();
    SecureStorage.beginAuthAttempt();
    final ownerA = SecureStorage.currentOwner;
    final adapter = _RecordAdapter();
    final client = ApiClient(storage, adapter: adapter);
    final call = client.patch('/auth/me', data: {'fullName': 'A edit'});
    // Attach error handling before releasing the asynchronous read.
    final result = expectLater(call, throwsA(isA<SessionChangedException>()));
    await storage.started.future;
    SecureStorage.beginAuthAttempt();
    await storage.withCredentialLock(() async {
      storage.markNewSession();
      await storage.saveRefreshToken('B-refresh');
      await storage.saveAccessToken('B-access');
    });
    storage.release.complete();
    await result;
    expect(adapter.calls, hasLength(1));
    expect(adapter.calls.single.headers['Authorization'], 'Bearer B-access');
    expect(adapter.calls.single.extra['session'], ownerA.generation);
    expect(adapter.calls.single.extra['attempt'], ownerA.attempt);
    expect(adapter.calls.single.data, {'fullName': 'A edit'});
    // The response check is too late: the mutation has already reached the transport under B.
  });
}
