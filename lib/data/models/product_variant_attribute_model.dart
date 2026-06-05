class ProductVariantAttributeModel {
  static String get createTableQuery => '''
    CREATE TABLE product_variant_attributes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      variant_id INTEGER NOT NULL,
      name TEXT NOT NULL DEFAULT '',
      value TEXT NOT NULL DEFAULT '',
      is_deleted INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT '',
      updated_at TEXT NOT NULL DEFAULT '',
      FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
    );
  ''';

  static String get createVariantIndexQuery => '''
    CREATE INDEX IF NOT EXISTS idx_product_variant_attributes_variant_id
    ON product_variant_attributes (variant_id, name);
  ''';

  ProductVariantAttributeModel({
    this.id,
    this.variantId,
    required this.name,
    required this.value,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
       updatedAt = updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final int? id;
  final int? variantId;
  final String name;
  final String value;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'variant_id': variantId,
    'name': name,
    'value': value,
    'is_deleted': isDeleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ProductVariantAttributeModel copyWith({
    int? id,
    int? variantId,
    String? name,
    String? value,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProductVariantAttributeModel(
    id: id ?? this.id,
    variantId: variantId ?? this.variantId,
    name: name ?? this.name,
    value: value ?? this.value,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory ProductVariantAttributeModel.fromMap(Map<String, Object?> map) {
    return ProductVariantAttributeModel(
      id: map['id'] as int?,
      variantId: map['variant_id'] as int?,
      name: map['name'] as String? ?? '',
      value: map['value'] as String? ?? '',
      isDeleted: _bool(map['is_deleted']),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
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
