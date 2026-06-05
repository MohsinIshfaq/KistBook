import '../../core/constants/api_urls.dart';
import '../../core/services/api_services.dart';

class RuntimeBootstrapRemoteDataSource {
  RuntimeBootstrapRemoteDataSource(this._apiServices);

  final ApiServices _apiServices;

  Future<Map<String, dynamic>> fetch() {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.get,
      endpoint: API.URL_BOOTSTRAP,
    );
  }
}
