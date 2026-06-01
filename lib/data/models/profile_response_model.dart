import '../../core/utils/dart_json.dart';
import 'company_model.dart';
import 'user_model.dart';

class ProfileResponseModel {
  const ProfileResponseModel({
    required this.user,
    this.company,
    this.role,
    required this.message,
    required this.rawResponse,
  });

  final UserModel? user;
  final CompanyModel? company;
  final String? role;
  final String message;
  final Map<String, dynamic> rawResponse;

  bool get isValid => user != null && !user!.isEmpty;

  factory ProfileResponseModel.fromJson(Map<String, dynamic> data) {
    final json = DartJson(data);
    final dataJson = json.jsonValue('data');
    final directUser = json.mapValue('user');
    final nestedUser = dataJson.mapValue('user');
    final userMap = directUser.isNotEmpty
        ? directUser
        : nestedUser.isNotEmpty
        ? nestedUser
        : dataJson.isNotEmpty
        ? dataJson.rawMap
        : json.rawMap;
    final user = UserModel.fromJson(userMap);
    final directCompany = json.mapValue('company');
    final companyMap = directCompany.isNotEmpty
        ? directCompany
        : dataJson.mapValue('company');

    return ProfileResponseModel(
      user: user.isEmpty ? null : user,
      company: companyMap.isEmpty ? null : CompanyModel.fromJson(companyMap),
      role:
          json.asString('role') ?? dataJson.asString('role') ?? user.userLevel,
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
