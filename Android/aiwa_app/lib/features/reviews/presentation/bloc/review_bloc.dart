import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/review_repository.dart';
import 'review_event.dart';
import 'review_state.dart';

class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  final ReviewRepository _repository;

  ReviewBloc(this._repository) : super(ReviewInitial()) {
    on<ReviewSubmitEvent>(_onSubmit);
  }

  Future<void> _onSubmit(
    ReviewSubmitEvent event,
    Emitter<ReviewState> emit,
  ) async {
    emit(ReviewLoading());
    final result = await _repository.submitReview(
      bookingId: event.bookingId,
      rating: event.rating,
      comment: event.comment,
      tags: event.tags,
    );
    result.fold(
      (f) => emit(ReviewError(f.message)),
      (_) => emit(ReviewSubmitted()),
    );
  }
}
