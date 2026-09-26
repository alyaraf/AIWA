import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../entities/provider_summary_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  });

  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> searchProviders({
    required String query,
    int page = 0,
    int size = 20,
  });
}
