import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../providers/domain/entities/provider_detail_entity.dart';
import '../repositories/booking_repository.dart';

class GetAvailableSlotsUseCase {
  final BookingRepository _repository;
  GetAvailableSlotsUseCase(this._repository);

  // Slots are fetched via ProviderRepository; this is a placeholder
  // that delegates to provider-specific availability.
  // In practice, availability is loaded through ProviderBloc.
  Future<Either<Failure, void>> call(String providerId, String date) async {
    return const Right(null);
  }
}
