import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/review_repository.dart';

class SubmitReviewUseCase {
  final ReviewRepository _repository;
  SubmitReviewUseCase(this._repository);

  Future<Either<Failure, void>> call({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags = const [],
  }) => _repository.submitReview(
    bookingId: bookingId,
    rating: rating,
    comment: comment,
    tags: tags,
  );
}
