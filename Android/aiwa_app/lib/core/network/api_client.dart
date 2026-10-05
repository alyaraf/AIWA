import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage.dart';
import '../theme/theme_controller.dart';

class ApiClient {
  late final Dio _dio;
  final SecureStorage _storage;

  /// Status codes the app routes to a system screen: 401 (refresh
  /// rejected), 403, 423. Listened to in app.dart.
  static final authEvents = StreamController<int>.broadcast();

  /// The backend's `code` on a 403 caused by the caller's role
  /// (SecurityConfig.ROLE_FORBIDDEN_CODE).
  static const roleForbiddenCode = 'auth.error.forbidden_role';

  /// Emits `true` on connection errors and `false` on the next response.
  static final offline = StreamController<bool>.broadcast();

  /// [adapter] is a test seam: goldens serve JSON fixtures through it.
  ApiClient(this._storage, {HttpClientAdapter? adapter}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.addAll([
      _AuthInterceptor(_storage, _dio),
      _ErrorInterceptor(),
    ]);
  }

  /// Dio wraps interceptor errors in [DioException]; hand callers the typed
  /// exception from `err.error` so repositories' `on XException` fire.
  static Future<Response<T>> _send<T>(Future<Response<T>> call) async {
    try {
      return await call;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is ServerException ||
          inner is UnauthorizedException ||
          inner is NetworkException) { // includes SessionChangedException
        throw inner!;
      }
      throw ServerException(
        message: 'Something went wrong',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _send(
    _dio.get<T>(path, queryParameters: queryParameters, options: options),
  );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _send(
    _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) =>
      _send(_dio.put<T>(path, data: data, options: options));

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _send(
    _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _send(
    _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    ),
  );

  /// Best effort: revokes the access and refresh tokens server-side. Never
  /// throws, so sign-out still works offline. Sign-out passes the tokens it
  /// read before clearing them (CR-18); otherwise the stored ones are used.
  Future<void> logout({String? accessToken, String? refreshToken}) async {
    try {
      refreshToken ??= await _storage.getRefreshToken();
      if (refreshToken == null) return;
      await _dio
          .post(
            ApiConstants.logout,
            data: {'refreshToken': refreshToken},
            // An expired access token must not trigger a refresh here.
            options: Options(
              headers: accessToken == null
                  ? null
                  : {'Authorization': 'Bearer $accessToken'},
              extra: {'retried': true},
            ),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<Response<T>> postForm<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) => _send(
    _dio.post<T>(
      path,
      data: formData,
      queryParameters: queryParameters,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    ),
  );
}

class _AuthInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Dio _dio;

  /// The in-flight refresh; concurrent 401s await it instead of failing.
  Future<String?>? _refreshing;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Backend picks messages_ar/en.properties from this header.
    options.headers['Accept-Language'] =
        LocaleController.locale.value.languageCode;
    // The session this request belongs to (DR-003).
    options.extra['session'] = SecureStorage.generation;
    final token = await _storage.getAccessToken();
    // A request that names its own token (clean-up after sign-out, CR-18)
    // keeps it: it must never go out under the next session's token.
    if (token != null &&
        token.isNotEmpty &&
        options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// M-01: a SUCCESSFUL answer for a request sent under an earlier session (the user signed out, or into another
  /// account, while it was in flight) must not reach the caller, which would cache it or show it as the current
  /// user's. Only the retry/401 path used to check the session.
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final sent = response.requestOptions.extra['session'];
    if (sent is int && sent != SecureStorage.generation) {
      return handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.cancel,
          error: const SessionChangedException(),
        ),
        true,
      );
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    // The refresh call itself and an already-retried request must not
    // trigger (or await) another refresh.
    if (err.response?.statusCode != 401 ||
        opts.path == ApiConstants.refresh ||
        opts.extra['retried'] == true) {
      return handler.next(err);
    }
    // Sent under a session that has since ended (sign-out / account switch):
    // never retry it with the next session's token.
    if (opts.extra['session'] != SecureStorage.generation) {
      return handler.next(err);
    }
    final refreshToken = await _storage.getRefreshToken();
    // No refresh token = never signed in (guest / sign-in form): a plain
    // 401, not an expired session.
    if (refreshToken == null) return handler.next(err);
    // Another request already refreshed after this one was sent: just retry
    // with the stored token instead of spending the new refresh token.
    final current = await _storage.getAccessToken();
    final String? newToken;
    if (current != null &&
        _refreshing == null &&
        opts.headers['Authorization'] != 'Bearer $current') {
      newToken = current;
    } else {
      try {
        newToken = await (_refreshing ??= _refresh(
          refreshToken,
        ).whenComplete(() => _refreshing = null));
      } on NetworkException {
        // Offline is not an expired session: keep the tokens.
        return handler.next(err);
      }
    }
    if (newToken == null || opts.extra['session'] != SecureStorage.generation) {
      return handler.next(err);
    }
    opts.headers['Authorization'] = 'Bearer $newToken';
    opts.extra['retried'] = true;
    // M-03: a multipart body is a one-shot stream and is already finalized by the first send, so the retry needs a
    // fresh copy (the files are re-read from their builders). Without this an avatar / gallery / ID-document upload
    // that hit an expired access token failed again even though the refresh worked.
    final body = opts.data;
    if (body is FormData) opts.data = body.clone();
    try {
      handler.resolve(await _dio.fetch(opts));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// New access token, or null when the refresh failed. Only a 401/403 from
  /// /auth/refresh (token rejected) signs the user out; 429 / 5xx / a bad
  /// body keep the tokens so the next request can try again. Throws
  /// [NetworkException] when offline.
  Future<String?> _refresh(String refreshToken) async {
    final session = SecureStorage.generation;
    String? token;
    String? rotated;
    try {
      final response = await _dio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {}),
      );
      token = response.data['data']['accessToken'] as String?;
      rotated = response.data['data']['refreshToken'] as String?;
    } on DioException catch (e) {
      if (e.error is NetworkException) throw e.error!;
      final status = e.response?.statusCode;
      // Only if it's still the same session: a stale refresh failing after an
      // account switch must not wipe the new account's tokens.
      if ((status == 401 || status == 403) && session == SecureStorage.generation) {
        await _storage.clearAll();
        ApiClient.authEvents.add(401);
      }
      return null;
    } catch (_) {}
    if (token == null) return null;
    // Signed out (or into another account) while this was in flight: drop it.
    if (session != SecureStorage.generation) return null;
    await _storage.saveAccessToken(token);
    // Refresh tokens are single-use: the backend revokes the one just sent,
    // so the next refresh must use the new one or the user is signed out.
    // Checked again: a sign-out during the write above must not get this
    // session's refresh token written back (CR-18).
    if (rotated != null &&
        rotated.isNotEmpty &&
        session == SecureStorage.generation) {
      await _storage.saveRefreshToken(rotated);
    }
    return token;
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ApiClient.offline.add(false);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(err.copyWith(error: mapError(err)));
  }

  static Exception mapError(DioException err) {
    if (err.error is SessionChangedException) {
      return err.error! as SessionChangedException; // not an outage: do not flip the offline banner
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        ApiClient.offline.add(true);
        return const NetworkException(message: 'Connection timed out');
      case DioExceptionType.connectionError:
        ApiClient.offline.add(true);
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        ApiClient.offline.add(false);
        final data = err.response?.data;
        final message = data is Map ? data['message'] as String? : null;
        final code = data is Map ? data['code'] as String? : null;
        if (statusCode == 401) return const UnauthorizedException();
        // 423 always; 403 only when the role was refused. A business 403
        // ("not your booking", "account suspended") carries its own code and
        // is shown inline by the screen, not as the Forbidden page (M-9).
        if (statusCode == 423 ||
            (statusCode == 403 &&
                (code == null || code == ApiClient.roleForbiddenCode))) {
          ApiClient.authEvents.add(statusCode!);
        }
        return ServerException(
          message: message ?? 'Something went wrong',
          statusCode: statusCode,
        );
      default:
        // Dio's own err.message is English developer text; keep the mapped
        // fallback so AiwaL10n.error() can translate it.
        return ServerException(
          message: 'Something went wrong',
          statusCode: err.response?.statusCode,
        );
    }
  }
}
