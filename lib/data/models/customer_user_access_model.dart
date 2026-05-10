import 'base_model.dart';

class CustomerUserAccessModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE customer_user_access (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      user_uuid TEXT NOT NULL,
      customer_uuid TEXT NOT NULL,
      is_sync INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  const CustomerUserAccessModel({
    this.id,
    required this.uuid,
    required this.userUuid,
    required this.customerUuid,
    required this.isSync,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int? id;
  final String uuid;
  final String userUuid;
  final String customerUuid;
  final bool isSync;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'uuid': uuid,
        'user_uuid': userUuid,
        'customer_uuid': customerUuid,
        'is_sync': isSync ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'uuid';

  @override
  Object? get uniqueKeyValue => uuid;

  factory CustomerUserAccessModel.fromMap(Map<String, Object?> map) =>
      CustomerUserAccessModel(
        id: map['id'] as int?,
        uuid: map['uuid'] as String? ?? '',
        userUuid: map['user_uuid'] as String? ?? '',
        customerUuid: map['customer_uuid'] as String? ?? '',
        isSync: (map['is_sync'] as num?)?.toInt() == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
