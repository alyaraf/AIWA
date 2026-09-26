import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class ReviewRepository {
  Future<Either<Failure, void>> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags,
  });
}
