import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/provider_detail_model.dart';

abstract class ProviderRemoteDataSource {
  Future<ProviderDetailModel> getProviderDetail(String providerId);
  Future<List<ServiceModel>> getProviderServices(String providerId);
  Future<List<ReviewSummaryModel>> getProviderReviews(String providerId,
      {int page = 0, int size = 10});
  Future<List<Map<String, dynamic>>> getAvailableSlots(
      String providerId, String date);
  Future<void> saveProvider(String providerId);
  Future<void> unsaveProvider(String providerId);
  Future<bool> isProviderSaved(String providerId);
}

class ProviderRemoteDataSourceImpl implements ProviderRemoteDataSource {
  final ApiClient _api;
  ProviderRemoteDataSourceImpl(this._api);

  @override
  Future<ProviderDetailModel> getProviderDetail(String providerId) async {
    final response = await _api.get(ApiConstants.providerProfile(providerId));
    final data = response.data['data'] ?? response.data;
    return ProviderDetailModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<ServiceModel>> getProviderServices(String providerId) async {
    final response =
        await _api.get(ApiConstants.providerServices(providerId));
    final data = response.data['data'] ?? response.data;
    final list = (data is List) ? data : (data['content'] as List? ?? []);
    return list
        .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ReviewSummaryModel>> getProviderReviews(String providerId,
      {int page = 0, int size = 10}) async {
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
      String providerId, String date) async {
    final response = await _api.get(
      ApiConstants.providerAvailability(providerId),
      queryParameters: {'date': date},
    );
    final data = response.data['data'] ?? response.data;
    final list = data is List ? data : [];
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<void> saveProvider(String providerId) async {
    await _api.post(ApiConstants.savedProviders, data: {'providerId': providerId});
  }

  @override
  Future<void> unsaveProvider(String providerId) async {
    await _api.delete('${ApiConstants.savedProviders}/$providerId');
  }

  @override
  Future<bool> isProviderSaved(String providerId) async {
    try {
      await _api.get('${ApiConstants.savedProviders}/$providerId');
      return true;
    } catch (_) {
      return false;
    }
  }
}
