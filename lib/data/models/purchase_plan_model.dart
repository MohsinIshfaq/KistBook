import 'dart:convert';

import 'base_model.dart';

class PlanProductSelection {
  const PlanProductSelection({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final int quantity;

  Map<String, Object?> toMap() => {
        'product_id': productId,
        'quantity': quantity,
      };

  factory PlanProductSelection.fromMap(Map<String, Object?> map) =>
      PlanProductSelection(
        productId: map['product_id'] as int,
        quantity: ((map['quantity'] as num?) ?? 1).toInt().clamp(1, 999999),
      );
}

class PurchasePlanModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE plans (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      product_id INTEGER,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      product_ids_text TEXT NOT NULL,
      product_selections_text TEXT NOT NULL,
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
    required this.quantity,
    required this.unitPrice,
    required this.productIds,
    required this.productSelections,
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
  final int quantity;
  final double unitPrice;
  final List<int> productIds;
  final List<PlanProductSelection> productSelections;
  final String itemName;
  final double totalAmount;
  final double depositAmount;
  final double installmentAmount;
  final int installmentCount;
  final int frequencyDays;
  final DateTime startDate;
  final String notes;
  final DateTime createdAt;

  int? get primaryProductId =>
      productId ?? (productIds.isEmpty ? null : productIds.first);

  PurchasePlanModel copyWith({
    int? id,
    int? customerId,
    int? productId,
    int? quantity,
    double? unitPrice,
    List<int>? productIds,
    List<PlanProductSelection>? productSelections,
    String? itemName,
    double? totalAmount,
    double? depositAmount,
    double? installmentAmount,
    int? installmentCount,
    int? frequencyDays,
    DateTime? startDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return PurchasePlanModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      productIds: productIds ?? this.productIds,
      productSelections: productSelections ?? this.productSelections,
      itemName: itemName ?? this.itemName,
      totalAmount: totalAmount ?? this.totalAmount,
      depositAmount: depositAmount ?? this.depositAmount,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      installmentCount: installmentCount ?? this.installmentCount,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      startDate: startDate ?? this.startDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'product_ids_text': productIds.join(','),
        'product_selections_text':
            jsonEncode(productSelections.map((item) => item.toMap()).toList()),
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
        quantity: ((map['quantity'] as num?) ?? 1).toInt(),
        unitPrice: ((map['unit_price'] as num?) ?? (map['total_amount'] as num)).toDouble(),
        productIds: _parseProductIds(
          map['product_ids_text'] as String?,
          fallbackProductId: map['product_id'] as int?,
        ),
        productSelections: _parseProductSelections(
          map['product_selections_text'] as String?,
          rawProductIds: map['product_ids_text'] as String?,
          fallbackProductId: map['product_id'] as int?,
        ),
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

  static List<int> _parseProductIds(String? raw, {int? fallbackProductId}) {
    final values = (raw ?? '')
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
    if (values.isNotEmpty) {
      return values;
    }
    return fallbackProductId == null ? const [] : [fallbackProductId];
  }

  static List<PlanProductSelection> _parseProductSelections(
    String? raw, {
    String? rawProductIds,
    int? fallbackProductId,
  }) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map(
                (item) => PlanProductSelection.fromMap(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList();
        }
      } catch (_) {
        // Fall through to legacy parsing.
      }
    }

    return _parseProductIds(
      rawProductIds,
      fallbackProductId: fallbackProductId,
    ).map((productId) => PlanProductSelection(productId: productId, quantity: 1)).toList();
  }
}
