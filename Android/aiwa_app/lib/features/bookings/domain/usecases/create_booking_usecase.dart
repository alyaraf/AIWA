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
    String? scheduledDate,
    String? scheduledTime,
    String? staffId,
    bool bookNow = false,
    bool homeService = false,
    String? savedAddressId,
    String? customerNote,
  }) => _repository.createBooking(
    providerId: providerId,
    serviceId: serviceId,
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    staffId: staffId,
    bookNow: bookNow,
    homeService: homeService,
    savedAddressId: savedAddressId,
    customerNote: customerNote,
  );
}
