import 'base_model.dart';

class CustomerModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      cnic TEXT NOT NULL,
      address TEXT NOT NULL,
      reference_name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  const CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    required this.cnic,
    required this.address,
    required this.reference,
    required this.createdAt,
  });

  @override
  final int? id;
  final String name;
  final String phone;
  final String cnic;
  final String address;
  final String reference;
  final DateTime createdAt;

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? cnic,
    String? address,
    String? reference,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      cnic: cnic ?? this.cnic,
      address: address ?? this.address,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'cnic': cnic,
        'address': address,
        'reference_name': reference,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'cnic';

  @override
  Object? get uniqueKeyValue => cnic;

  factory CustomerModel.fromMap(Map<String, Object?> map) => CustomerModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        cnic: map['cnic'] as String? ?? '',
        address: map['address'] as String? ?? '',
        reference: map['reference_name'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
