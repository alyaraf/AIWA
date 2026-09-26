import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/notification_entity.dart';
import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  final NotificationRepository _repository;
  GetNotificationsUseCase(this._repository);

  Future<Either<Failure, PagedData<NotificationEntity>>> call({
    int page = 0,
    int size = 20,
  }) =>
      _repository.getNotifications(page: page, size: size);
}
