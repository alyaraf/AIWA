import 'package:equatable/equatable.dart';

abstract class ReviewEvent extends Equatable {
  const ReviewEvent();
  @override
  List<Object?> get props => [];
}

class ReviewSubmitEvent extends ReviewEvent {
  final String bookingId;
  final double rating;
  final String? comment;
  final List<String> tags;

  const ReviewSubmitEvent({
    required this.bookingId,
    required this.rating,
    this.comment,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [bookingId, rating, comment, tags];
}
