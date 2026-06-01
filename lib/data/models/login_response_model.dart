import '../../core/utils/dart_json.dart';
import 'company_model.dart';
import 'user_model.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    required this.user,
    this.company,
    this.role,
    required this.message,
    required this.rawResponse,
  });

  final String token;
  final UserModel? user;
  final CompanyModel? company;
  final String? role;
  final String message;
  final Map<String, dynamic> rawResponse;

  bool get isValid => token.trim().isNotEmpty && user != null && !user!.isEmpty;

  factory LoginResponseModel.fromJson(Map<String, dynamic> data) {
    final json = DartJson(data);
    final dataJson = json.jsonValue('data');
    final token =
        json.asString('token') ??
        json.asString('access_token') ??
        dataJson.asString('token') ??
        dataJson.asString('access_token') ??
        '';
    final directUser = json.mapValue('user');
    final userMap = directUser.isNotEmpty
        ? directUser
        : dataJson.mapValue('user');
    final directCompany = json.mapValue('company');
    final companyMap = directCompany.isNotEmpty
        ? directCompany
        : dataJson.mapValue('company');

    return LoginResponseModel(
      token: token,
      user: userMap.isEmpty ? null : UserModel.fromJson(userMap),
      company: companyMap.isEmpty ? null : CompanyModel.fromJson(companyMap),
      role: json.asString('role') ?? dataJson.asString('role'),
      message: _messageFrom(json),
      rawResponse: json.rawMap,
    );
  }

  static String _messageFrom(DartJson json) {
    return json.asString('message') ??
        json.asString('Message') ??
        json.asString('error') ??
        'Something went wrong. Please try again.';
  }
}
