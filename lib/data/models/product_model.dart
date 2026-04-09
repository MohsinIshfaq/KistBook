import 'base_model.dart';

class ProductModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      brand_name TEXT NOT NULL,
      name TEXT NOT NULL,
      sku TEXT NOT NULL,
      sale_price REAL NOT NULL,
      notes TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''';

  const ProductModel({
    this.id,
    required this.brandName,
    required this.name,
    required this.sku,
    required this.salePrice,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int? id;
  final String brandName;
  final String name;
  final String sku;
  final double salePrice;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'brand_name': brandName,
        'name': name,
        'sku': sku,
        'sale_price': salePrice,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'sku';

  @override
  Object? get uniqueKeyValue => sku;

  factory ProductModel.fromMap(Map<String, Object?> map) => ProductModel(
        id: map['id'] as int?,
        brandName: map['brand_name'] as String? ?? '',
        name: map['name'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        salePrice: (map['sale_price'] as num).toDouble(),
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(
          (map['updated_at'] as String?) ?? (map['created_at'] as String),
        ),
      );
}
