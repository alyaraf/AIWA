import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository _repository;
  CreateBookingUseCase(this._repository);

  Future<Either<Failure, BookingEntity>> call({
    required String providerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    String? customerNote,
  }) =>
      _repository.createBooking(
        providerId: providerId,
        serviceId: serviceId,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        customerNote: customerNote,
      );
}
