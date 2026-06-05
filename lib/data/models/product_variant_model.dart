import 'product_variant_attribute_model.dart';

class ProductVariantModel {
  static String get createTableQuery => '''
    CREATE TABLE product_variants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      server_id TEXT,
      sku TEXT NOT NULL DEFAULT '',
      sale_price REAL NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
    );
  ''';

  static String get createProductIndexQuery => '''
    CREATE INDEX IF NOT EXISTS idx_product_variants_product_id
    ON product_variants (product_id, server_id);
  ''';

  ProductVariantModel({
    this.id,
    this.productId,
    this.serverId,
    required this.sku,
    required this.salePrice,
    this.attributes = const [],
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final int? id;
  final int? productId;
  final String? serverId;
  final String sku;
  final double salePrice;
  final List<ProductVariantAttributeModel> attributes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'server_id': serverId,
    'sku': sku,
    'sale_price': salePrice,
    'is_deleted': isDeleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ProductVariantModel copyWith({
    int? id,
    int? productId,
    String? serverId,
    String? sku,
    double? salePrice,
    List<ProductVariantAttributeModel>? attributes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductVariantModel(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    serverId: serverId ?? this.serverId,
    sku: sku ?? this.sku,
    salePrice: salePrice ?? this.salePrice,
    attributes: attributes ?? this.attributes,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ProductVariantModel.fromMap(
    Map<String, Object?> map, {
    List<ProductVariantAttributeModel> attributes = const [],
  }) {
    return ProductVariantModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      serverId: _string(map['server_id']),
      sku: map['sku'] as String? ?? '',
      salePrice: _double(map['sale_price']),
      attributes: attributes,
      isDeleted: _bool(map['is_deleted']),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }

  static String? _string(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static double _double(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() != 0;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  static DateTime _date(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
