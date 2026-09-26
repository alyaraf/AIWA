import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../../home/domain/entities/provider_summary_entity.dart';
import '../../domain/repositories/saved_repository.dart';
import '../datasources/saved_remote_datasource.dart';

class SavedRepositoryImpl implements SavedRepository {
  final SavedRemoteDataSource _remote;
  SavedRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getSavedProviders({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result =
          await _remote.getSavedProviders(page: page, size: size);
      return Right(PagedData(
        content: result.content,
        totalElements: result.totalElements,
        totalPages: result.totalPages,
        number: result.number,
        size: result.size,
        last: result.last,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeProvider(String providerId) async {
    try {
      await _remote.removeProvider(providerId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
