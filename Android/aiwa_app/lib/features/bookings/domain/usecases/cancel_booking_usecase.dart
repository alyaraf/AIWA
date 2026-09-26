import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class CancelBookingUseCase {
  final BookingRepository _repository;
  CancelBookingUseCase(this._repository);

  Future<Either<Failure, BookingEntity>> call(String bookingId) =>
      _repository.cancelBooking(bookingId);
}
