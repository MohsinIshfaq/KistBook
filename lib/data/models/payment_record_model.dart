import 'base_model.dart';

class PaymentRecordModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      plan_id INTEGER NOT NULL,
      installment_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      paid_on TEXT NOT NULL,
      note TEXT NOT NULL
    );
  ''';

  const PaymentRecordModel({
    this.id,
    required this.customerId,
    required this.planId,
    required this.installmentId,
    required this.amount,
    required this.paidOn,
    required this.note,
  });

  @override
  final int? id;
  final int customerId;
  final int planId;
  final int installmentId;
  final double amount;
  final DateTime paidOn;
  final String note;

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'plan_id': planId,
        'installment_id': installmentId,
        'amount': amount,
        'paid_on': paidOn.toIso8601String(),
        'note': note,
      };

  @override
  String get uniqueKey => 'id';

  @override
  Object? get uniqueKeyValue => id;

  factory PaymentRecordModel.fromMap(Map<String, Object?> map) => PaymentRecordModel(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int,
        planId: map['plan_id'] as int,
        installmentId: map['installment_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        paidOn: DateTime.parse(map['paid_on'] as String),
        note: map['note'] as String? ?? '',
      );
}
