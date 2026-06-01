import '../../core/utils/dart_json.dart';
import 'company_model.dart';
import 'user_model.dart';

class RegisterResponseModel {
  const RegisterResponseModel({
    required this.token,
    required this.user,
    required this.company,
    required this.message,
    required this.rawResponse,
  });

  final String token;
  final UserModel? user;
  final CompanyModel? company;
  final String message;
  final Map<String, dynamic> rawResponse;

  bool get isValid =>
      token.trim().isNotEmpty &&
      user != null &&
      !user!.isEmpty &&
      company != null &&
      !company!.isEmpty;

  factory RegisterResponseModel.fromJson(Map<String, dynamic> data) {
    final json = DartJson(data);
    final dataJson = json.jsonValue('data');
    final token =
        json.asString('token') ??
        json.asString('access_token') ??
        dataJson.asString('token') ??
        dataJson.asString('access_token') ??
        '';
    final userMap = _firstMap(json, dataJson, 'user');
    final companyMap = _firstMap(json, dataJson, 'company');

    return RegisterResponseModel(
      token: token,
      user: userMap.isEmpty ? null : UserModel.fromJson(userMap),
      company: companyMap.isEmpty ? null : CompanyModel.fromJson(companyMap),
      message: _messageFrom(json),
      rawResponse: json.rawMap,
    );
  }

  static Map<String, dynamic> _firstMap(
    DartJson json,
    DartJson dataJson,
    String key,
  ) {
    final direct = json.mapValue(key);
    return direct.isNotEmpty ? direct : dataJson.mapValue(key);
  }

  static String _messageFrom(DartJson json) {
    return json.asString('message') ??
        json.asString('Message') ??
        json.asString('error') ??
        'Something went wrong. Please try again.';
  }
}
