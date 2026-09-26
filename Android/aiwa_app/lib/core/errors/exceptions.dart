class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({required this.message, this.statusCode});
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'No internet connection'});
}

class CacheException implements Exception {
  final String message;
  const CacheException({required this.message});
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;
  const ValidationException({required this.message, this.fieldErrors});
}
