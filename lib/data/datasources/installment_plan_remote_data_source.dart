import '../../core/constants/api_urls.dart';
import '../../core/services/api_services.dart';
import '../sync/sync_batch_models.dart';

class InstallmentPlanRemoteDataSource {
  InstallmentPlanRemoteDataSource(this._apiServices);

  final ApiServices _apiServices;

  Future<SyncUploadResult> create(List<Map<String, Object?>> plans) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_INSTALLMENT_PLAN_SYNC,
      body: {'plans': plans},
    );
    return SyncUploadResult.fromJson(response);
  }

  Future<SyncUploadResult> update(List<Map<String, Object?>> plans) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.put,
      endpoint: API.URL_INSTALLMENT_PLAN_SYNC,
      body: {'plans': plans},
    );
    return SyncUploadResult.fromJson(response);
  }

  Future<SyncUploadResult> delete(List<Map<String, Object?>> plans) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.delete,
      endpoint: API.URL_INSTALLMENT_PLAN_SYNC,
      body: {'plans': plans},
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
      endpoint: API.URL_INSTALLMENT_PLAN_SYNC,
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
}
