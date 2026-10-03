import 'dart:convert';
import 'dart:typed_data';

import 'package:aiwa_app/core/network/api_client.dart';
import 'package:aiwa_app/core/storage/secure_storage.dart';
import 'package:aiwa_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:aiwa_app/features/auth/data/models/user_model.dart';
import 'package:aiwa_app/features/profile/data/account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// CR-05 request shapes: UpdateProfileRequest.currentPassword,
/// AuthRequest.ChangePhone.currentPassword, AuthRequest.VerifyEmail and the
/// DELETE /account CurrentPassword body (U05 backend).
class _Recorder implements HttpClientAdapter {
  final calls = <({String method, String path, Object? body})>[];
  int status = 200;
  String reply = '{"success":true,"data":null}';

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    return ResponseBody.fromString(
      reply,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _userJson = {
  'id': 7,
  'fullName': 'Salma Adel',
  'email': 'old@example.com',
  'pendingEmail': 'new@example.com',
  'role': 'CUSTOMER',
};

void main() {
  late _Recorder http;
  late ApiClient api;
  late AuthRemoteDataSourceImpl remote;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    http = _Recorder();
    api = ApiClient(SecureStorage(const FlutterSecureStorage()), adapter: http);
    remote = AuthRemoteDataSourceImpl(api);
  });

  test('GET /auth/me pendingEmail reaches the user', () {
    expect(UserModel.fromJson(_userJson).pendingEmail, 'new@example.com');
    expect(
      UserModel.fromJson({..._userJson, 'pendingEmail': null}).pendingEmail,
      isNull,
    );
  });

  test('PATCH /auth/me carries currentPassword with a new email', () async {
    http.reply = jsonEncode({'success': true, 'data': _userJson});
    final u = await remote.updateProfile(
      fullName: 'Salma Adel',
      email: 'new@example.com',
      currentPassword: 'pw',
    );
    expect(http.calls.single.method, 'PATCH');
    expect(http.calls.single.path, endsWith('/auth/me'));
    expect(http.calls.single.body, {
      'fullName': 'Salma Adel',
      'email': 'new@example.com',
      'currentPassword': 'pw',
    });
    expect(u.pendingEmail, 'new@example.com');
  });

  test('PATCH /auth/me without a password sends none', () async {
    http.reply = jsonEncode({'success': true, 'data': _userJson});
    await remote.updateProfile(fullName: 'Salma Adel');
    expect(http.calls.single.body, {'fullName': 'Salma Adel'});
  });

  test('PATCH /auth/me/phone carries code and currentPassword', () async {
    http.reply = jsonEncode({
      'success': true,
      'data': {'accessToken': 'a', 'refreshToken': 'r'},
    });
    final t = await remote.changePhone(
      phone: '+201009998888',
      code: '654321',
      currentPassword: 'pw',
    );
    expect(http.calls.single.path, endsWith('/auth/me/phone'));
    expect(http.calls.single.body, {
      'phone': '+201009998888',
      'code': '654321',
      'currentPassword': 'pw',
    });
    expect(t, {'accessToken': 'a', 'refreshToken': 'r'});
  });

  test(
    'POST /auth/me/email/verify sends the code, returns fresh tokens',
    () async {
      http.reply = jsonEncode({
        'success': true,
        'data': {'accessToken': 'a2', 'refreshToken': 'r2'},
      });
      final t = await remote.verifyEmail(code: '123456');
      expect(http.calls.single.method, 'POST');
      expect(http.calls.single.path, endsWith('/auth/me/email/verify'));
      expect(http.calls.single.body, {'code': '123456'});
      expect(t, {'accessToken': 'a2', 'refreshToken': 'r2'});
    },
  );

  test(
    'DELETE /account sends currentPassword; wrong password is a failure',
    () async {
      final repo = AccountRepository(api);
      expect(
        (await repo.deleteAccount(currentPassword: 'pw')).isRight(),
        isTrue,
      );
      expect(http.calls.single.method, 'DELETE');
      expect(http.calls.single.path, endsWith('/account'));
      expect(http.calls.single.body, {'currentPassword': 'pw'});

      http.status = 400;
      http.reply = '{"message":"Your current password is not correct"}';
      final r = await repo.deleteAccount(currentPassword: 'nope');
      expect(
        r.fold((f) => f.message, (_) => null),
        'Your current password is not correct',
      );
    },
  );
}
