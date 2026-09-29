import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/provider_detail_entity.dart';
import '../../domain/repositories/provider_repository.dart';
import '../datasources/provider_remote_datasource.dart';

class ProviderRepositoryImpl implements ProviderRepository {
  final ProviderRemoteDataSource _remote;
  ProviderRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, ProviderDetailEntity>> getProviderDetail(
    String providerId,
  ) async {
    try {
      final result = await _remote.getProviderDetail(providerId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ServiceEntity>>> getProviderServices(
    String providerId,
  ) async {
    try {
      final result = await _remote.getProviderServices(providerId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<ReviewSummaryEntity>>> getProviderReviews(
    String providerId, {
    int page = 0,
    int size = 10,
  }) async {
    try {
      final result = await _remote.getProviderReviews(
        providerId,
        page: page,
        size: size,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AvailabilitySlot>>> getAvailableSlots(
    String providerId,
    String serviceId,
    String date, {
    String? staffId,
  }) async {
    try {
      final raw = await _remote.getAvailableSlots(
        providerId,
        serviceId,
        date,
        staffId: staffId,
      );
      return Right([
        AvailabilitySlot(
          date: DateTime.parse(date),
          times: [
            for (final s in raw)
              if (s['booked'] != true) s['startTime'].toString(),
          ],
          booked: [
            for (final s in raw)
              if (s['booked'] == true) s['startTime'].toString(),
          ],
        ),
      ]);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> saveProvider(String providerId) async {
    try {
      await _remote.saveProvider(providerId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> unsaveProvider(String providerId) async {
    try {
      await _remote.unsaveProvider(providerId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isProviderSaved(String providerId) async {
    try {
      final saved = await _remote.isProviderSaved(providerId);
      return Right(saved);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reportPhoto(
    String providerId,
    String imageId,
    String reason,
  ) async {
    try {
      await _remote.reportPhoto(providerId, imageId, reason);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> flagProvider(
    String providerId,
    String reason,
    String note,
  ) async {
    try {
      await _remote.flagProvider(providerId, reason, note);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
