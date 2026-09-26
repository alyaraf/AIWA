import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../../home/data/models/provider_summary_model.dart';

abstract class SavedRemoteDataSource {
  Future<PagedData<ProviderSummaryModel>> getSavedProviders({
    int page = 0,
    int size = 20,
  });

  Future<void> removeProvider(String providerId);
}

class SavedRemoteDataSourceImpl implements SavedRemoteDataSource {
  final ApiClient _api;
  SavedRemoteDataSourceImpl(this._api);

  @override
  Future<PagedData<ProviderSummaryModel>> getSavedProviders({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConstants.savedProviders,
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data['data'] ?? response.data;
    return PagedData.fromJson(
      data,
      (e) => ProviderSummaryModel.fromJson(e as Map<String, dynamic>),
    );
  }

  @override
  Future<void> removeProvider(String providerId) async {
    await _api.delete('${ApiConstants.savedProviders}/$providerId');
  }
}
