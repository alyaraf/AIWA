import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/provider_detail_entity.dart';
import '../repositories/provider_repository.dart';

class GetProviderSlotsUseCase {
  final ProviderRepository _repository;
  GetProviderSlotsUseCase(this._repository);

  /// [date] is `yyyy-MM-dd`.
  Future<Either<Failure, List<AvailabilitySlot>>> call(
    String providerId,
    String serviceId,
    String date,
  ) => _repository.getAvailableSlots(providerId, serviceId, date);
}
