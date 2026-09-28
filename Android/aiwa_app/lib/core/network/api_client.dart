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

  /// Emits `true` on connection errors and `false` on the next response.
  static final offline = StreamController<bool>.broadcast();

  ApiClient(this._storage) {
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
          inner is NetworkException) {
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
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _send(
    _dio.delete<T>(path, queryParameters: queryParameters, options: options),
  );

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
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Backend picks messages_ar/en.properties from this header.
    options.headers['Accept-Language'] =
        LocaleController.locale.value.languageCode;
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      final refreshToken = await _storage.getRefreshToken();
      // No refresh token = never signed in (guest / sign-in form): a plain
      // 401, not an expired session.
      if (refreshToken == null) return handler.next(err);
      _isRefreshing = true;
      String? newToken;
      try {
        final response = await _dio.post(
          ApiConstants.refresh,
          data: {'refreshToken': refreshToken},
          options: Options(headers: {}),
        );
        newToken = response.data['data']['accessToken'] as String?;
      } on DioException catch (e) {
        // Offline is not an expired session: keep the tokens.
        if (e.error is NetworkException) {
          _isRefreshing = false;
          return handler.next(err);
        }
      } catch (_) {}
      _isRefreshing = false;
      if (newToken == null) {
        await _storage.clearAll();
        ApiClient.authEvents.add(401);
        return handler.next(err);
      }
      await _storage.saveAccessToken(newToken);
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      try {
        return handler.resolve(await _dio.fetch(err.requestOptions));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(err);
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
        if (statusCode == 401) return const UnauthorizedException();
        if (statusCode == 403 || statusCode == 423) {
          ApiClient.authEvents.add(statusCode!);
        }
        return ServerException(
          message: message ?? 'Something went wrong',
          statusCode: statusCode,
        );
      default:
        return ServerException(
          message: err.message ?? 'Something went wrong',
          statusCode: err.response?.statusCode,
        );
    }
  }
}
