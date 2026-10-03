import 'package:dio/dio.dart' show Options;
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';

/// Returns this device's push token, or null when push isn't available.
typedef PushTokenSource = Future<String?> Function();

/// Keeps the backend's push address for this device in step with the session
/// (FE-3): registered on every sign-in / session restore, cleared on sign-out
/// so a shared phone stops getting the previous user's notifications.
///
/// The token itself comes from [tokenSource]. Until the Firebase project
/// exists (OPS-3 / FE-28) the default source returns null and this is a no-op;
/// wiring Firebase is then one line in injection_container.dart:
///   tokenSource: () => FirebaseMessaging.instance.getToken()
class PushRegistrar {
  PushRegistrar(this._api, {PushTokenSource? tokenSource, String? platform})
    : _tokenSource = tokenSource ?? _noToken,
      _platform = platform ?? (_isIOS ? 'IOS' : 'ANDROID');

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  final ApiClient _api;
  final PushTokenSource _tokenSource;
  final String _platform;

  static Future<String?> _noToken() async => null;

  /// Best effort: a failed registration must never block sign-in.
  Future<void> register() async {
    try {
      final token = await _tokenSource();
      if (token == null || token.isEmpty) return;
      await _api.patch(
        ApiConstants.mePushToken,
        data: {'token': token, 'platform': _platform},
      );
    } catch (_) {}
  }

  /// Call while the session is still valid, i.e. before revoking tokens.
  /// Removes only this phone (R2-12: the backend keeps one entry per phone, so
  /// signing out here no longer stops pushes on the user's other phones).
  /// [accessToken]: the session's token when it was already cleared from
  /// storage (sign-out, CR-18).
  Future<void> unregister({String? accessToken}) async {
    try {
      String? token;
      try {
        token = await _tokenSource();
      } catch (_) {}
      await _api.delete(
        ApiConstants.mePushToken,
        queryParameters: token == null || token.isEmpty ? null : {'token': token},
        options: accessToken == null
            ? null
            : Options(
                headers: {'Authorization': 'Bearer $accessToken'},
                extra: {'retried': true},
              ),
      );
    } catch (_) {}
  }
}
