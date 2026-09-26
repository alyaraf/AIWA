import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

abstract class ReviewRemoteDataSource {
  Future<void> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags,
  });
}

class ReviewRemoteDataSourceImpl implements ReviewRemoteDataSource {
  final ApiClient _api;
  ReviewRemoteDataSourceImpl(this._api);

  @override
  Future<void> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    await _api.post(ApiConstants.reviews, data: {
      'bookingId': bookingId,
      'rating': rating,
      if (comment != null) 'comment': comment,
      if (tags.isNotEmpty) 'tags': tags,
    });
  }
}
