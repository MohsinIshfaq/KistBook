import 'base_model.dart';

class ProductPriceHistoryModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE product_price_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      previous_price REAL,
      new_price REAL NOT NULL,
      changed_at TEXT NOT NULL
    );
  ''';

  const ProductPriceHistoryModel({
    this.id,
    required this.productId,
    this.previousPrice,
    required this.newPrice,
    required this.changedAt,
  });

  @override
  final int? id;
  final int productId;
  final double? previousPrice;
  final double newPrice;
  final DateTime changedAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'product_id': productId,
        'previous_price': previousPrice,
        'new_price': newPrice,
        'changed_at': changedAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'id';

  @override
  Object? get uniqueKeyValue => id;

  factory ProductPriceHistoryModel.fromMap(Map<String, Object?> map) =>
      ProductPriceHistoryModel(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        previousPrice: map['previous_price'] == null
            ? null
            : (map['previous_price'] as num).toDouble(),
        newPrice: (map['new_price'] as num).toDouble(),
        changedAt: DateTime.parse(map['changed_at'] as String),
      );
}
