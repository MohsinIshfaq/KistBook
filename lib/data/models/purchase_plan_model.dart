import 'base_model.dart';

class PurchasePlanModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      product_id INTEGER,
      item_name TEXT NOT NULL,
      total_amount REAL NOT NULL,
      deposit_amount REAL NOT NULL,
      installment_amount REAL NOT NULL,
      installment_count INTEGER NOT NULL,
      frequency_days INTEGER NOT NULL,
      start_date_iso TEXT NOT NULL,
      notes TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''';

  const PurchasePlanModel({
    this.id,
    required this.customerId,
    this.productId,
    required this.itemName,
    required this.totalAmount,
    required this.depositAmount,
    required this.installmentAmount,
    required this.installmentCount,
    required this.frequencyDays,
    required this.startDate,
    required this.notes,
    required this.createdAt,
  });

  @override
  final int? id;
  final int customerId;
  final int? productId;
  final String itemName;
  final double totalAmount;
  final double depositAmount;
  final double installmentAmount;
  final int installmentCount;
  final int frequencyDays;
  final DateTime startDate;
  final String notes;
  final DateTime createdAt;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'product_id': productId,
        'item_name': itemName,
        'total_amount': totalAmount,
        'deposit_amount': depositAmount,
        'installment_amount': installmentAmount,
        'installment_count': installmentCount,
        'frequency_days': frequencyDays,
        'start_date_iso': startDate.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  String get uniqueKey => 'id';

  @override
  Object? get uniqueKeyValue => id;

  factory PurchasePlanModel.fromMap(Map<String, Object?> map) => PurchasePlanModel(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int,
        productId: map['product_id'] as int?,
        itemName: map['item_name'] as String? ?? '',
        totalAmount: (map['total_amount'] as num).toDouble(),
        depositAmount: (map['deposit_amount'] as num).toDouble(),
        installmentAmount: (map['installment_amount'] as num).toDouble(),
        installmentCount: map['installment_count'] as int,
        frequencyDays: map['frequency_days'] as int,
        startDate: DateTime.parse(map['start_date_iso'] as String),
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
