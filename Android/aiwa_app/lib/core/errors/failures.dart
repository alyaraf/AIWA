import 'package:equatable/equatable.dart';

// ponytail: dartz Either + Exception->Failure remap in every repo; plain throw/catch or a sealed Result would cut dartz, revisit if repos get rewritten
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Unauthorized. Please sign in again.');
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors});
}

/// The backend has no endpoint for this yet; the UI is built against it so
/// wiring the real call is a one-line change in the repository.
class NotSupportedFailure extends Failure {
  const NotSupportedFailure(String what) : super('$what isn’t supported yet.');
}
