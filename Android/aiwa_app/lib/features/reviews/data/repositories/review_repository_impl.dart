import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/review_remote_datasource.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ReviewRemoteDataSource _remote;
  ReviewRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, void>> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags = const [],
    String? direction,
  }) async {
    try {
      await _remote.submitReview(
        bookingId: bookingId,
        rating: rating,
        comment: comment,
        tags: tags,
        direction: direction,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
