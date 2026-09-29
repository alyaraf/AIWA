import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_response.dart';
import '../../domain/entities/provider_summary_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;
  HomeRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> getNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await _remote.getNearbyProviders(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        category: category,
        sort: sort,
        page: page,
        size: size,
      );
      // ponytail: field-by-field copy of a PagedData the datasource already returns; `return Right(result);` works (Model extends Entity, generics are covariant)
      return Right(
        PagedData(
          content: result.content,
          totalElements: result.totalElements,
          totalPages: result.totalPages,
          number: result.number,
          size: result.size,
          last: result.last,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, PagedData<ProviderSummaryEntity>>> searchProviders({
    required String query,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final result = await _remote.searchProviders(
        query: query,
        page: page,
        size: size,
      );
      // ponytail: field-by-field copy of a PagedData the datasource already returns; `return Right(result);` works (Model extends Entity, generics are covariant)
      return Right(
        PagedData(
          content: result.content,
          totalElements: result.totalElements,
          totalPages: result.totalPages,
          number: result.number,
          size: result.size,
          last: result.last,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  /// POST /providers/waitlist — one alert when a matching provider is approved.
  @override
  Future<Either<Failure, void>> notifyWhenProviderJoins({
    String? category,
    double? lat,
    double? lng,
  }) async {
    try {
      await _remote.joinWaitlist(category: category, lat: lat, lng: lng);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
