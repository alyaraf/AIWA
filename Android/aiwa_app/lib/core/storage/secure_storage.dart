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

  Future<void> clearAll() {
    _generation++;
    return _storage.deleteAll();
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
