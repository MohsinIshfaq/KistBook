import 'base_model.dart';

class ProductImageModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE product_images (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      image_path TEXT NOT NULL,
      sort_order INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
    );
  ''';

  static String get createProductIndexQuery => '''
    CREATE INDEX IF NOT EXISTS idx_product_images_product_id
    ON product_images (product_id, sort_order);
  ''';

  const ProductImageModel({
    this.id,
    required this.productId,
    required this.imagePath,
    required this.sortOrder,
    required this.createdAt,
  });

  @override
  final int? id;
  final int productId;
  final String imagePath;
  final int sortOrder;
  final DateTime createdAt;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'product_id': productId,
    'image_path': imagePath,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  String get uniqueKey => 'id';

  @override
  Object? get uniqueKeyValue => id;

  factory ProductImageModel.fromMap(Map<String, Object?> map) =>
      ProductImageModel(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        imagePath: map['image_path'] as String? ?? '',
        sortOrder: map['sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
