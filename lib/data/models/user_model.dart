import '../../core/constants/app_enums.dart';
import '../../core/utils/dart_json.dart';

class UserModel {
  const UserModel({
    this.id = 0,
    this.uuid,
    this.companyId = 0,
    this.name = '',
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
    this.userLevel,
    this.userLevelId = 0,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? uuid;
  final int companyId;
  final String name;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;
  final String? userLevel;
  final int userLevelId;
  final bool? isActive;
  final String? createdAt;
  final String? updatedAt;

  String get serverId {
    final normalizedUuid = uuid?.trim() ?? '';
    if (normalizedUuid.isNotEmpty) {
      return normalizedUuid;
    }
    return id > 0 ? '$id' : '';
  }

  String get fullName {
    final explicitName = name.trim();
    if (explicitName.isNotEmpty) {
      return explicitName;
    }
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  bool get isEmpty =>
      serverId.isEmpty &&
      fullName.isEmpty &&
      (email?.trim().isEmpty ?? true) &&
      (phone?.trim().isEmpty ?? true);

  UserRole get role => switch (userLevel?.toLowerCase()) {
    'owner' => UserRole.owner,
    'admin' => UserRole.admin,
    _ => UserRole.salesMan,
  };

  factory UserModel.fromJson(Map<String, dynamic> data) {
    final json = DartJson(data);

    return UserModel(
      id: json.intValue('id'),
      uuid: _firstString(json, ['uuid', 'server_id']),
      companyId: json.intValue('company_id'),
      name: json.stringValue('name'),
      email: json.asString('email'),
      phone: json.asString('phone'),
      firstName: _firstString(json, ['first_name', 'firstName']),
      lastName: _firstString(json, ['last_name', 'lastName']),
      userLevel: _firstString(json, ['access_level', 'user_level', 'role']),
      userLevelId: json.intValue('user_level_id'),
      isActive: json.has('is_active')
          ? json.asBool('is_active')
          : json.has('isActive')
          ? json.asBool('isActive')
          : json.asString('status') == 'active',
      createdAt: json.asString('created_at'),
      updatedAt: json.asString('updated_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'company_id': companyId,
    'name': name,
    'email': email,
    'phone': phone,
    'first_name': firstName,
    'last_name': lastName,
    'access_level': userLevel,
    'role': userLevel,
    'user_level_id': userLevelId,
    'is_active': isActive,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  static String? _firstString(DartJson json, List<String> keys) {
    for (final key in keys) {
      final value = json.asString(key);
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
