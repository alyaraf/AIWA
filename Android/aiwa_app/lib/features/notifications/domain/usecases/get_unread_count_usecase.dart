import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/notification_repository.dart';

class GetUnreadCountUseCase {
  final NotificationRepository _repository;
  GetUnreadCountUseCase(this._repository);

  Future<Either<Failure, int>> call() => _repository.getUnreadCount();
}
