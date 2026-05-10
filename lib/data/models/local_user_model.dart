import '../../core/constants/app_enums.dart';
import 'base_model.dart';

class LocalUserModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      phone TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      role TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_sync INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  const LocalUserModel({
    this.id,
    required this.uuid,
    required this.phone,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isActive,
    required this.isSync,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int? id;
  final String uuid;
  final String phone;
  final String password;
  final String firstName;
  final String lastName;
  final UserRole role;
  final bool isActive;
  final bool isSync;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$firstName $lastName'.trim();

  LocalUserModel copyWith({
    int? id,
    String? uuid,
    String? phone,
    String? password,
    String? firstName,
    String? lastName,
    UserRole? role,
    bool? isActive,
    bool? isSync,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocalUserModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isSync: isSync ?? this.isSync,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'uuid': uuid,
        'phone': phone,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'role': role.name,
        'is_active': isActive ? 1 : 0,
        'is_sync': isSync ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'uuid';

  @override
  Object? get uniqueKeyValue => uuid;

  factory LocalUserModel.fromMap(Map<String, Object?> map) => LocalUserModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        password: map['password'] as String? ?? '',
        firstName: map['first_name'] as String? ?? '',
        lastName: map['last_name'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (item) => item.name == (map['role'] as String? ?? ''),
          orElse: () => UserRole.salesMan,
        ),
        isActive: (map['is_active'] as num?)?.toInt() == 1,
        isSync: (map['is_sync'] as num?)?.toInt() == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
