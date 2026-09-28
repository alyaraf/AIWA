import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class GetMyBookingsUseCase {
  final BookingRepository _repository;
  GetMyBookingsUseCase(this._repository);

  Future<Either<Failure, PagedData<BookingEntity>>> call({
    String? status,
    int page = 0,
    int size = 20,
  }) => _repository.getMyBookings(status: status, page: page, size: size);
}
