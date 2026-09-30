import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

abstract class ReviewRemoteDataSource {
  Future<void> submitReview({
    required String bookingId,
    required double rating,
    String? comment,
    List<String> tags,
    String? direction,
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
    String? direction,
  }) async {
    await _api.post(
      ApiConstants.reviews,
      data: {
        'bookingId': bookingId,
        'rating': rating,
        'comment': ?comment,
        // ReviewRequest.quickTags; direction defaults to CUSTOMER_TO_PROVIDER.
        if (tags.isNotEmpty) 'quickTags': tags,
        'direction': ?direction,
      },
    );
  }
}
