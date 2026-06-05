import '../../core/constants/api_urls.dart';
import '../../core/services/api_services.dart';
import '../sync/sync_batch_models.dart';

class ProductRemoteDataSource {
  ProductRemoteDataSource(this._apiServices);

  final ApiServices _apiServices;

  Future<SyncUploadResult> create(List<Map<String, Object?>> products) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_PRODUCT_SYNC,
      body: {'products': products},
    );
    return SyncUploadResult.fromJson(response);
  }

  Future<SyncUploadResult> update(List<Map<String, Object?>> products) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.put,
      endpoint: API.URL_PRODUCT_SYNC,
      body: {'products': products},
    );
    return SyncUploadResult.fromJson(response);
  }

  Future<SyncUploadResult> delete(List<Map<String, Object?>> products) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.delete,
      endpoint: API.URL_PRODUCT_SYNC,
      body: {'products': products},
    );
    return SyncUploadResult.fromJson(response);
  }

  Future<SyncDownloadResult> download({
    String? lastUpdatedAt,
    String? lastServerId,
    int limit = 10,
  }) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.get,
      endpoint: API.URL_PRODUCT_SYNC,
      queryParameters: {
        if (lastUpdatedAt != null && lastUpdatedAt.isNotEmpty)
          'lastUpdatedAt': lastUpdatedAt,
        if (lastServerId != null && lastServerId.isNotEmpty)
          'lastServerId': lastServerId,
        'limit': '$limit',
      },
    );
    return SyncDownloadResult.fromJson(response);
  }

  Future<Map<String, dynamic>> detail(String serverId) {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.get,
      endpoint: API.URL_PRODUCT_DETAIL(serverId),
    );
  }

  Future<List<int>> downloadImage(String url) {
    return _apiServices.downloadBytes(url: url);
  }
}
