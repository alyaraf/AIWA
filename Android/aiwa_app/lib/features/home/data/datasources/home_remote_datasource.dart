import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../models/provider_summary_model.dart';

abstract class HomeRemoteDataSource {
  Future<PagedData<ProviderSummaryModel>> getNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  });

  Future<PagedData<ProviderSummaryModel>> searchProviders({
    required String query,
    int page = 0,
    int size = 20,
  });
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _client;
  HomeRemoteDataSourceImpl(this._client);

  @override
  Future<PagedData<ProviderSummaryModel>> getNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 10,
    String? category,
    String sort = 'distance',
    int page = 0,
    int size = 20,
  }) async {
    final params = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
      'sort': sort,
      'page': page,
      'size': size,
    };
    if (category != null) params['category'] = category;

    final response = await _client.get(
      ApiConstants.nearbyProviders,
      queryParameters: params,
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
    return PagedData.fromJson(
      data['data'] as Map<String, dynamic>,
      ProviderSummaryModel.fromJson,
    );
  }

  @override
  Future<PagedData<ProviderSummaryModel>> searchProviders({
    required String query,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _client.get(
      ApiConstants.searchProviders,
      queryParameters: {'q': query, 'page': page, 'size': size},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw ServerException(message: data['message'] as String? ?? 'Failed');
    }
    return PagedData.fromJson(
      data['data'] as Map<String, dynamic>,
      ProviderSummaryModel.fromJson,
    );
  }
}
