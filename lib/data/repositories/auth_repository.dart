import '../../core/constants/api_urls.dart';
import '../../core/services/api_services.dart';

class AuthRepository {
  AuthRepository(this._apiServices);

  final ApiServices _apiServices;

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_LOGIN,
      body: {'login': login, 'password': password},
      useBearerToken: false,
    );
  }

  Future<Map<String, dynamic>> registerOwner({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String companyName,
    String? companyPhone,
    String? companyAddress,
  }) {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_REGISTER,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'company_name': companyName,
        'company_phone': companyPhone,
        'company_address': companyAddress,
      },
      useBearerToken: false,
    );
  }

  Future<Map<String, dynamic>> createCompanyUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_CREATE_COMPANY_USER,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> getProfile() {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.get,
      endpoint: API.URL_PROFILE,
    );
  }

  Future<Map<String, dynamic>> logout() {
    return _apiServices.sendRequest(
      method: ApiRequestMethod.post,
      endpoint: API.URL_LOGOUT,
    );
  }
}
