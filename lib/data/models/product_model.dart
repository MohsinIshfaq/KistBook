import 'dart:convert';

import 'base_model.dart';

class ProductModel implements BaseModel {
  static const defaultCategory = 'General';

  static String get createTableQuery => '''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      categories_text TEXT NOT NULL,
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
    required this.categories,
    required this.brandName,
    required this.name,
    required this.sku,
    required this.salePrice,
    required this.notes,
    this.imagePaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final int? id;
  final List<String> categories;
  final String brandName;
  final String name;
  final String sku;
  final double salePrice;
  final String notes;
  final List<String> imagePaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'categories_text': jsonEncode(categories),
    'brand_name': brandName,
    'name': name,
    'sku': sku,
    'sale_price': salePrice,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ProductModel copyWith({
    int? id,
    List<String>? categories,
    String? brandName,
    String? name,
    String? sku,
    double? salePrice,
    String? notes,
    List<String>? imagePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductModel(
    id: id ?? this.id,
    categories: categories ?? this.categories,
    brandName: brandName ?? this.brandName,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    salePrice: salePrice ?? this.salePrice,
    notes: notes ?? this.notes,
    imagePaths: imagePaths ?? this.imagePaths,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String get uniqueKey => 'sku';

  @override
  Object? get uniqueKeyValue => sku;

  factory ProductModel.fromMap(Map<String, Object?> map) => ProductModel(
    id: map['id'] as int?,
    categories: _parseCategories(
      map['categories_text'] as String?,
      fallbackCategory: map['category'] as String?,
    ),
    brandName: map['brand_name'] as String? ?? '',
    name: map['name'] as String? ?? '',
    sku: map['sku'] as String? ?? '',
    salePrice: (map['sale_price'] as num).toDouble(),
    notes: map['notes'] as String? ?? '',
    imagePaths: const [],
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(
      (map['updated_at'] as String?) ?? (map['created_at'] as String),
    ),
  );

  static List<String> _parseCategories(
    String? raw, {
    String? fallbackCategory,
  }) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final values = decoded
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (values.isNotEmpty) {
            return values;
          }
        }
      } catch (_) {
        // Fall back to legacy parsing below.
      }
    }

    final fallback = (fallbackCategory ?? '').trim();
    return fallback.isEmpty ? const [defaultCategory] : [fallback];
  }
}
