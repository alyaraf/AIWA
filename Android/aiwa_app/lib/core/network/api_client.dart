import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage.dart';
import '../theme/theme_controller.dart';

/// R6-02: a status the app routes globally (401 / 403 / 423) together with the session that produced it. The consumer
/// (app.dart) drops it unless [owner] is still current when it is delivered, so a late answer for account A can never
/// sign out or redirect account B.
class SessionEvent {
  final int status;
  final SessionOwner owner;
  const SessionEvent(this.status, this.owner);

  @override
  String toString() => 'SessionEvent($status, $owner)';
}

class ApiClient {
  late final Dio _dio;
  final SecureStorage _storage;

  /// Status codes the app routes to a system screen: 401 (refresh
  /// rejected), 403, 423, each tagged with the session that produced it (R6-02). Listened to in app.dart.
  static final authEvents = StreamController<SessionEvent>.broadcast();

  /// The backend's `code` on a 403 caused by the caller's role
  /// (SecurityConfig.ROLE_FORBIDDEN_CODE).
  static const roleForbiddenCode = 'auth.error.forbidden_role';

  /// SEC-04: [RequestOptions.extra] flag of an intentional clean-up request (sign-out revocation, push-token removal)
  /// that carries the credentials of the session it belongs to, explicitly, after that session was cleared. Such a
  /// request is exempt from the pre-dispatch ownership check, and never receives the stored token.
  static const ownCredentialsExtra = 'ownCredentials';

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
  /// SEC-02: resolves true only when the server confirmed the revocation (2xx); false when it could not (offline,
  /// 503 durable-revocation failure, timeout). Local sign-out proceeds either way; callers may surface the false.
  Future<bool> logout({String? accessToken, String? refreshToken}) async {
    try {
      refreshToken ??= await _storage.getRefreshToken();
      if (refreshToken == null) return true;
      await _dio
          .post(
            ApiConstants.logout,
            data: {'refreshToken': refreshToken},
            // An expired access token must not trigger a refresh here.
            options: Options(
              headers: accessToken == null
                  ? null
                  : {'Authorization': 'Bearer $accessToken'},
              extra: {'retried': true, ownCredentialsExtra: true},
            ),
          )
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
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

  /// The in-flight refresh; concurrent 401s await it instead of failing. It belongs to one session: a request of
  /// another session (the user signed into a different account meanwhile) must never wait for it or take its token.
  Future<String?>? _refreshing;
  int? _refreshingSession;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Backend picks messages_ar/en.properties from this header.
    options.headers['Accept-Language'] =
        LocaleController.locale.value.languageCode;
    // The session this request belongs to (DR-003), and (R6-02) the credential operation (sign-in / registration /
    // sign-out) that was current: a failed answer may only act globally while both are still current. A retry keeps
    // the owner it was first sent under (SEC-04): it must not adopt whoever is current when it is re-dispatched.
    final session = options.extra['session'];
    final attempt = options.extra['attempt'];
    final owner = session is int && attempt is int
        ? SessionOwner(session, attempt)
        : SecureStorage.currentOwner;
    options.extra['session'] = owner.generation;
    options.extra['attempt'] = owner.attempt;
    // A clean-up request that names its own token (after sign-out, CR-18) goes out exactly as built: never under
    // the next session's token, and not dropped because that next session already exists.
    if (options.extra[ApiClient.ownCredentialsExtra] == true) {
      return handler.next(options);
    }
    String? token;
    if (options.headers['Authorization'] == null) {
      token = await _storage.getAccessToken();
    }
    // SEC-04: ownership is checked after the asynchronous credential read and immediately before dispatch. If the
    // session ended or another sign-in / account switch began meanwhile, the credentials just read may belong to
    // the next account, and a mutation sent with them would be performed as that account (the response check in
    // onResponse comes too late to undo it). The obsolete request is dropped before the transport.
    if (!SecureStorage.owns(owner)) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const SessionChangedException(),
        ),
        true,
      );
    }
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
    final session = SecureStorage.generation;
    final refreshToken = await _storage.getRefreshToken();
    // The read above may already belong to the next account (R5-01).
    if (session != SecureStorage.generation) return handler.next(err);
    // No refresh token = never signed in (guest / sign-in form): a plain
    // 401, not an expired session.
    if (refreshToken == null) return handler.next(err);
    // Another request already refreshed after this one was sent: just retry
    // with the stored token instead of spending the new refresh token.
    final current = await _storage.getAccessToken();
    final String? newToken;
    if (session != SecureStorage.generation) return handler.next(err);
    if (current != null &&
        _refreshing == null &&
        opts.headers['Authorization'] != 'Bearer $current') {
      newToken = current;
    } else {
      try {
        if (_refreshing == null || _refreshingSession != session) {
          late final Future<String?> mine;
          mine = _refresh(refreshToken, session, opts.extra['attempt'] as int?).whenComplete(() {
            if (identical(_refreshing, mine)) {
              _refreshing = null;
              _refreshingSession = null;
            }
          });
          _refreshing = mine;
          _refreshingSession = session;
        }
        newToken = await _refreshing;
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
  Future<String?> _refresh(String refreshToken, int session, int? attempt) async {
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
      // R5-01: the clear re-checks the session inside the credential lock, so a stale refresh failing after an
      // account switch neither wipes the new account's tokens nor announces a sign-out for it.
      if ((status == 401 || status == 403) &&
          await _storage.clearIfSession(session)) {
        // The clear ended [session], so the signed-out state is the next generation, under the request's operation.
        ApiClient.authEvents.add(
          SessionEvent(401, SessionOwner(session + 1, attempt ?? SecureStorage.authAttempt)),
        );
      }
      return null;
    } catch (_) {}
    if (token == null) return null;
    // Refresh tokens are single-use: the backend revokes the one just sent, so the next refresh must use the new
    // one or the user is signed out. Both tokens are stored in one step that re-checks, under the credential lock,
    // that this is still the session that asked: a sign-out or another account's sign-in during the write wins.
    final stored = await _storage.storeRefreshedTokens(
      session: session,
      accessToken: token,
      refreshToken: rotated,
    );
    return stored ? token : null;
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

  /// The session and credential operation a request was sent under; null for a request that never went through
  /// [_AuthInterceptor.onRequest] (it is then treated as current).
  static SessionOwner? _ownerOf(RequestOptions options) {
    final session = options.extra['session'];
    final attempt = options.extra['attempt'];
    return session is int && attempt is int ? SessionOwner(session, attempt) : null;
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
          // R6-02: only the session that sent the request may act on its answer. A late 423 / role 403 for account A
          // (B signed in, or is signing in, meanwhile) is dropped here, and the stale caller is told the session changed.
          final owner = _ownerOf(err.requestOptions);
          if (owner != null && !SecureStorage.owns(owner)) {
            return const SessionChangedException();
          }
          ApiClient.authEvents.add(
            SessionEvent(statusCode!, owner ?? SecureStorage.currentOwner),
          );
        }
        return ServerException(
          message: message ?? 'Something went wrong',
          statusCode: statusCode,
          code: code,
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
