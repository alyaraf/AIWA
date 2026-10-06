// SEC-04 (security audit 2026-10-06): ownership is verified after the asynchronous credential read and right before
// dispatch. An obsolete ordinary request produces zero transport calls and never carries another account's bearer
// token; intentional clean-up requests that name their original token still go out. Real ApiClient / Dio path.
import 'dart:async';
import 'dart:typed_data';

import 'package:aiwa_app/core/constants/api_constants.dart';
import 'package:aiwa_app/core/constants/app_constants.dart';
import 'package:aiwa_app/core/errors/exceptions.dart';
import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Secure storage whose access-token read can be held, to model a read serviced after another credential operation.
class _HeldRead extends SecureStorage {
  _HeldRead() : super(const FlutterSecureStorage());
  Completer<void>? started;
  Completer<void>? release;

  void hold() {
    started = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<String?> getAccessToken() async {
    final s = started, r = release;
    if (s != null && !s.isCompleted) s.complete();
    if (r != null) await r.future;
    return super.getAccessToken();
  }
}

class _RecordAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  /// Answers 401 to the first call to [expire401Path]; other calls succeed.
  String? expire401Path;
  void Function()? onRefresh;
  bool _expired = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add(o);
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (o.path == ApiConstants.refresh) {
      onRefresh?.call();
      return ResponseBody.fromString('{"data":{"accessToken":"A-fresh","refreshToken":"A-refresh-2"}}', 200, headers: headers);
    }
    if (stream != null) await stream.drain();
    if (expire401Path == o.path && !_expired) {
      _expired = true;
      return ResponseBody.fromString('{"message":"expired"}', 401, headers: headers);
    }
    return ResponseBody.fromString('{"data":{"fullName":"ok"}}', 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _switchToB(_HeldRead storage) async {
  SecureStorage.beginAuthAttempt();
  await storage.withCredentialLock(() async {
    storage.markNewSession();
    await storage.saveRefreshToken('B-refresh');
    await storage.saveAccessToken('B-access');
  });
}

void main() {
  late _HeldRead storage;
  late _RecordAdapter adapter;
  late ApiClient client;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.accessTokenKey: 'A-access',
      AppConstants.refreshTokenKey: 'A-refresh',
    });
    storage = _HeldRead();
    storage.markNewSession();
    SecureStorage.beginAuthAttempt();
    adapter = _RecordAdapter();
    client = ApiClient(storage, adapter: adapter);
  });

  test('a delayed credential read for the current session still sends the request with its own token', () async {
    storage.hold();
    final call = client.patch('/auth/me', data: {'fullName': 'A edit'});
    await storage.started!.future;
    storage.release!.complete();
    await call;
    expect(adapter.calls, hasLength(1));
    expect(adapter.calls.single.headers['Authorization'], 'Bearer A-access');
  });

  test('account switch during the token read: zero transport calls, never B\'s bearer', () async {
    storage.hold();
    final call = client.patch('/auth/me', data: {'fullName': 'A edit'});
    final outcome = expectLater(call, throwsA(isA<SessionChangedException>()));
    await storage.started!.future;
    await _switchToB(storage);
    storage.release!.complete();
    await outcome;
    expect(adapter.calls, isEmpty);
  });

  test('sign-out during the token read: the request is dropped before the transport', () async {
    storage.hold();
    final call = client.post('/bookings', data: {'x': 1});
    final outcome = expectLater(call, throwsA(isA<SessionChangedException>()));
    await storage.started!.future;
    SecureStorage.beginAuthAttempt();
    await storage.withCredentialLock(() async {
      storage.markNewSession();
      await const FlutterSecureStorage().deleteAll();
    });
    storage.release!.complete();
    await outcome;
    expect(adapter.calls, isEmpty);
  });

  test('an overlapping sign-in that began during the read (no new credentials yet) also drops the request', () async {
    storage.hold();
    final call = client.patch('/auth/me', data: {'fullName': 'A edit'});
    final outcome = expectLater(call, throwsA(isA<SessionChangedException>()));
    await storage.started!.future;
    SecureStorage.beginAuthAttempt(); // another sign-in starts; the generation has not changed yet
    storage.release!.complete();
    await outcome;
    expect(adapter.calls, isEmpty);
  });

  test('an upload obsolete during the credential read is never transmitted', () async {
    storage.hold();
    final call = client.postForm(
      '/auth/me/avatar',
      formData: FormData.fromMap({'image': MultipartFile.fromBytes([1, 2, 3], filename: 'a.png')}),
    );
    final outcome = expectLater(call, throwsA(isA<SessionChangedException>()));
    await storage.started!.future;
    await _switchToB(storage);
    storage.release!.complete();
    await outcome;
    expect(adapter.calls, isEmpty);
  });

  test('a retry after refresh keeps its original owner: if another sign-in began meanwhile it is not re-sent', () async {
    adapter.expire401Path = '/auth/me';
    // The refresh succeeds, but another credential operation begins while it is answered.
    adapter.onRefresh = SecureStorage.beginAuthAttempt;
    await expectLater(client.patch('/auth/me', data: {'fullName': 'A edit'}), throwsA(isA<SessionChangedException>()));
    final paths = adapter.calls.map((c) => c.path).toList();
    expect(paths, ['/auth/me', ApiConstants.refresh]); // no second /auth/me
  });

  test('a retry of a current-session request after refresh is still sent, with the refreshed token', () async {
    adapter.expire401Path = '/auth/me';
    await client.patch('/auth/me', data: {'fullName': 'A edit'});
    final mine = adapter.calls.where((c) => c.path == '/auth/me').toList();
    expect(mine, hasLength(2));
    expect(mine.last.headers['Authorization'], 'Bearer A-fresh');
  });

  test('intentional clean-up with the original token still goes out after the next account is installed', () async {
    await _switchToB(storage);
    await client.logout(accessToken: 'A-access', refreshToken: 'A-refresh');
    final call = adapter.calls.singleWhere((c) => c.path == ApiConstants.logout);
    expect(call.headers['Authorization'], 'Bearer A-access');
    expect(call.data, {'refreshToken': 'A-refresh'});
  });

  test('clean-up without an explicit access token never borrows the stored (next account\'s) token', () async {
    await _switchToB(storage);
    await client.logout(refreshToken: 'A-refresh');
    final call = adapter.calls.singleWhere((c) => c.path == ApiConstants.logout);
    expect(call.headers['Authorization'], isNull);
  });

  test('a custom explicit-credential request (push-token removal) is exempt from the ownership drop', () async {
    await _switchToB(storage);
    await client.delete(
      '/me/push-token',
      options: Options(
        headers: {'Authorization': 'Bearer A-access'},
        extra: {'retried': true, ApiClient.ownCredentialsExtra: true},
      ),
    );
    expect(adapter.calls.single.headers['Authorization'], 'Bearer A-access');
  });
}
