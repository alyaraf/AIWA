import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/provider_detail_model.dart';

abstract class ProviderRemoteDataSource {
  Future<ProviderDetailModel> getProviderDetail(String providerId);
  Future<List<ServiceModel>> getProviderServices(String providerId);
  Future<List<ReviewSummaryModel>> getProviderReviews(
    String providerId, {
    int page = 0,
    int size = 10,
  });
  Future<List<Map<String, dynamic>>> getAvailableSlots(
    String providerId,
    String serviceId,
    String date,
  );
  Future<void> saveProvider(String providerId);
  Future<void> unsaveProvider(String providerId);
  Future<bool> isProviderSaved(String providerId);
  Future<void> flagProvider(String providerId, String reason, String note);
}

class ProviderRemoteDataSourceImpl implements ProviderRemoteDataSource {
  final ApiClient _api;
  ProviderRemoteDataSourceImpl(this._api);

  @override
  Future<ProviderDetailModel> getProviderDetail(String providerId) async {
    // ponytail: a failed reviews call shows "No reviews yet" rather than
    // failing the whole profile.
    final reviews = getProviderReviews(
      providerId,
    ).then((r) => r, onError: (_) => const <ReviewSummaryModel>[]);
    final response = await _api.get(ApiConstants.providerProfile(providerId));
    return ProviderDetailModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
      reviews: await reviews,
    );
  }

  @override
  Future<List<ServiceModel>> getProviderServices(String providerId) async {
    final response = await _api.get(ApiConstants.providerServices(providerId));
    final data = response.data['data'] ?? response.data;
    final list = (data is List) ? data : (data['content'] as List? ?? []);
    return list
        .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ReviewSummaryModel>> getProviderReviews(
    String providerId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _api.get(
      ApiConstants.providerReviews(providerId),
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data['data'] ?? response.data;
    final list = (data is List) ? data : (data['content'] as List? ?? []);
    return list
        .map((e) => ReviewSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableSlots(
    String providerId,
    String serviceId,
    String date,
  ) async {
    // List<TimeSlotDto {startTime, endTime, booked}>.
    final response = await _api.get(
      ApiConstants.availableSlots,
      queryParameters: {
        'providerId': providerId,
        'serviceId': serviceId,
        'date': date,
      },
    );
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<void> saveProvider(String providerId) async {
    await _api.post('${ApiConstants.savedProviders}/$providerId');
  }

  @override
  Future<void> unsaveProvider(String providerId) async {
    await _api.delete('${ApiConstants.savedProviders}/$providerId');
  }

  @override
  Future<bool> isProviderSaved(String providerId) async {
    final response = await _api.get(ApiConstants.checkSaved(providerId));
    return response.data['data'] as bool? ?? false;
  }

  /// POST /complaints takes query params, not a body (ComplaintController).
  @override
  Future<void> flagProvider(
    String providerId,
    String reason,
    String note,
  ) async {
    await _api.post(
      ApiConstants.complaints,
      queryParameters: {
        'targetProviderId': providerId,
        'category': reason,
        'description': note.trim().isEmpty ? reason : note.trim(),
      },
    );
  }
}
