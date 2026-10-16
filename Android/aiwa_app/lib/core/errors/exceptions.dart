class ServerException implements Exception {
  final String message;
  final int? statusCode;

  /// The API's error code (`terms.error.not_accepted`, ...), when it sent one.
  final String? code;
  const ServerException({required this.message, this.statusCode, this.code});
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class NetworkException implements Exception {
  final String message;
  const NetworkException({this.message = 'No internet connection'});
}

/// A response arrived for a request that was sent under a session that has since ended (sign-out, expiry, account
/// switch). It is not an outage and not the new session's data, so it is dropped (audit M-01). It extends
/// [NetworkException] so repositories that only know the three API exceptions still turn it into a failure instead of
/// crashing; the blocs check the session generation themselves and emit nothing for it.
class SessionChangedException extends NetworkException {
  const SessionChangedException() : super(message: 'The session changed');
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
