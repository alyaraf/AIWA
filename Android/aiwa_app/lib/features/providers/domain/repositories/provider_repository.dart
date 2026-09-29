import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/provider_detail_entity.dart';

abstract class ProviderRepository {
  Future<Either<Failure, ProviderDetailEntity>> getProviderDetail(
    String providerId,
  );

  Future<Either<Failure, List<ServiceEntity>>> getProviderServices(
    String providerId,
  );

  Future<Either<Failure, List<ReviewSummaryEntity>>> getProviderReviews(
    String providerId, {
    int page = 0,
    int size = 10,
  });

  /// [staffId]: the picked stylist, so their own hours and bookings apply.
  Future<Either<Failure, List<AvailabilitySlot>>> getAvailableSlots(
    String providerId,
    String serviceId,
    String date, {
    String? staffId,
  });

  Future<Either<Failure, void>> saveProvider(String providerId);

  Future<Either<Failure, void>> unsaveProvider(String providerId);

  Future<Either<Failure, bool>> isProviderSaved(String providerId);

  /// Report one gallery photo to moderation.
  Future<Either<Failure, void>> reportPhoto(
    String providerId,
    String imageId,
    String reason,
  );

  Future<Either<Failure, void>> flagProvider(
    String providerId,
    String reason,
    String note,
  );
}
