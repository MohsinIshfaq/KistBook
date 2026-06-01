import '../../core/utils/dart_json.dart';

class CompanyModel {
  const CompanyModel({
    this.id = 0,
    this.uuid,
    this.name = '',
    this.phone,
    this.email,
    this.address,
    this.ownerId = 0,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String? uuid;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int ownerId;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  bool get isEmpty =>
      id == 0 && (uuid?.trim().isEmpty ?? true) && name.trim().isEmpty;

  factory CompanyModel.fromJson(Map<String, dynamic> data) {
    final json = DartJson(data);

    return CompanyModel(
      id: json.intValue('id'),
      uuid: json.asString('uuid'),
      name: json.stringValue('name'),
      phone: json.asString('phone'),
      email: json.asString('email'),
      address: json.asString('address'),
      ownerId: json.intValue('owner_id'),
      status: json.asString('status'),
      createdAt: json.asString('created_at'),
      updatedAt: json.asString('updated_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'owner_id': ownerId,
    'status': status,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}
