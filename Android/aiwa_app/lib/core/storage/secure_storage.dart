import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage(this._storage);

  /// Bumped when a session ends (sign-out, expiry) or a new one starts
  /// (sign-in, account switch). A token refresh that was in flight across
  /// such a change must not store its result (DR-003): it used to sign a
  /// user who had just signed out straight back in, highest risk on a
  /// shared phone.
  static int _generation = 0;
  static int get generation => _generation;

  /// Call before storing the tokens of a new sign-in.
  void markNewSession() => _generation++;

  /// R4-05: counts the credential-changing operations that START (sign-in, registration, sign-out). An operation
  /// remembers its own number and is obsolete once a newer one has started: it must not store tokens, clear storage
  /// or publish a state, because the newer operation owns the credentials now. (The session [generation] only changes
  /// when tokens are stored or cleared, which is too late to protect an operation that is still waiting for the server.)
  static int _attempt = 0;
  static int get authAttempt => _attempt;
  static int beginAuthAttempt() => ++_attempt;
  static bool isCurrentAttempt(int attempt) => attempt == _attempt;

  static Future<void> _credentialLock = Future<void>.value();

  /// Runs [body] while no other credential write or wipe is running, so two operations can never interleave their
  /// token writes (an access token of one account next to the refresh token of another).
  Future<T> withCredentialLock<T>(Future<T> Function() body) {
    final previous = _credentialLock;
    final done = Completer<void>();
    _credentialLock = done.future;
    return previous.then((_) => body()).whenComplete(done.complete);
  }

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: AppConstants.accessTokenKey, value: token);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConstants.refreshTokenKey, value: token);

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> saveUserRole(String role) =>
      _storage.write(key: AppConstants.userRoleKey, value: role);

  Future<String?> getUserRole() => _storage.read(key: AppConstants.userRoleKey);

  Future<void> saveUserId(String id) =>
      _storage.write(key: AppConstants.userIdKey, value: id);

  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);

  /// The signed-in user as last fetched (JSON), so a cold start without a
  /// network still opens signed in (L-14). Removed by [clearAll].
  Future<void> saveCachedUser(String json) =>
      _storage.write(key: 'cached_user', value: json);

  Future<String?> getCachedUser() => _storage.read(key: 'cached_user');

  Future<void> deleteCachedUser() => _storage.delete(key: 'cached_user');

  /// The provider sign-up checkpoint (ProviderSetupCheckpoint JSON: no password, OTP, contact or token). Removed by
  /// [clearAll], so a sign-out never leaves one behind for the next account.
  Future<void> saveSetupCheckpoint(String json) =>
      _storage.write(key: 'provider_setup_checkpoint', value: json);

  Future<String?> getSetupCheckpoint() =>
      _storage.read(key: 'provider_setup_checkpoint');

  Future<void> deleteSetupCheckpoint() =>
      _storage.delete(key: 'provider_setup_checkpoint');

  Future<void> clearAll() {
    _generation++;
    // Queued behind a credential write that is running, so the wipe is the last word.
    return withCredentialLock(() => _storage.deleteAll());
  }

  /// Sign-in "Remember me" off: the session ends at the next cold start.
  Future<void> setRemember(bool remember) => remember
      ? _storage.delete(key: 'remember_me')
      : _storage.write(key: 'remember_me', value: 'false');

  Future<bool> getRemember() async =>
      await _storage.read(key: 'remember_me') != 'false';

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
