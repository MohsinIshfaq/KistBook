import '../data/models/login_response_model.dart';
import '../data/models/profile_response_model.dart';
import '../data/models/register_response_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../core/utils/dart_json.dart';
import '../core/services/api_services.dart';

class AuthApiService {
  AuthApiService(this._authRepository);

  final AuthRepository _authRepository;

  Future<LoginResponseModel> login({
    required String login,
    required String password,
  }) async {
    return LoginResponseModel.fromJson(
      await _authRepository.login(login: login, password: password),
    );
  }

  Future<RegisterResponseModel> registerOwner({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String companyName,
    String? companyPhone,
    String? companyAddress,
  }) async {
    return RegisterResponseModel.fromJson(
      await _authRepository.registerOwner(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        companyName: companyName,
        companyPhone: companyPhone,
        companyAddress: companyAddress,
      ),
    );
  }

  Future<UserModel> createCompanyUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = DartJson(
      await _authRepository.createCompanyUser(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
      ),
    );
    final directUser = response.mapValue('user');
    final userMap = directUser.isNotEmpty
        ? directUser
        : response.jsonValue('data').mapValue('user');
    final user = UserModel.fromJson(userMap);
    if (user.isEmpty) {
      throw const ApiException(
        message:
            'The server returned incomplete salesman information. Please try again.',
      );
    }
    return user;
  }

  Future<ProfileResponseModel> getProfile() async {
    return ProfileResponseModel.fromJson(await _authRepository.getProfile());
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }
}
