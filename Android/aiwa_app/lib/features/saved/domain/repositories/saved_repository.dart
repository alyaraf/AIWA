import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../home/domain/entities/provider_summary_entity.dart';

abstract class SavedRepository {
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getSavedProviders({
    int page = 0,
    int size = 20,
  });

  Future<Either<Failure, void>> removeProvider(String providerId);
}
