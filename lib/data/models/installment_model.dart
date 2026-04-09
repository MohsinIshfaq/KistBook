import '../../core/constants/app_enums.dart';
import '../../core/utils/date_helper.dart';
import 'base_model.dart';

class InstallmentModel implements BaseModel {
  static String get createTableQuery => '''
    CREATE TABLE installments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      plan_id INTEGER NOT NULL,
      sequence_number INTEGER NOT NULL,
      scheduled_due_date TEXT NOT NULL,
      current_due_date TEXT NOT NULL,
      amount REAL NOT NULL,
      paid_amount REAL NOT NULL,
      status TEXT NOT NULL
    );
  ''';

  const InstallmentModel({
    this.id,
    required this.planId,
    required this.sequenceNumber,
    required this.scheduledDueDate,
    required this.currentDueDate,
    required this.amount,
    required this.paidAmount,
    required this.status,
  });

  @override
  final int? id;
  final int planId;
  final int sequenceNumber;
  final DateTime scheduledDueDate;
  final DateTime currentDueDate;
  final double amount;
  final double paidAmount;
  final InstallmentRecordStatus status;

  double get remainingAmount => amount - paidAmount;
  bool get isPaid => remainingAmount <= 0.009;
  bool get wasMissed => status == InstallmentRecordStatus.missed;

  InstallmentVisualStatus visualStatus(DateTime today) {
    if (isPaid) {
      return InstallmentVisualStatus.paid;
    }
    if (wasMissed || scheduledDueDate.isBefore(DateHelper.startOfDay(today))) {
      return InstallmentVisualStatus.overdue;
    }
    return InstallmentVisualStatus.pending;
  }

  @override
  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'sequence_number': sequenceNumber,
        'scheduled_due_date': scheduledDueDate.toIso8601String(),
        'current_due_date': currentDueDate.toIso8601String(),
        'amount': amount,
        'paid_amount': paidAmount,
        'status': status.name,
      };

  @override
  String get uniqueKey => 'id';

  @override
  Object? get uniqueKeyValue => id;

  factory InstallmentModel.fromMap(Map<String, Object?> map) => InstallmentModel(
        id: map['id'] as int?,
        planId: map['plan_id'] as int,
        sequenceNumber: map['sequence_number'] as int,
        scheduledDueDate: DateTime.parse(map['scheduled_due_date'] as String),
        currentDueDate: DateTime.parse(map['current_due_date'] as String),
        amount: (map['amount'] as num).toDouble(),
        paidAmount: (map['paid_amount'] as num).toDouble(),
        status: InstallmentRecordStatus.values.firstWhere(
          (value) => value.name == (map['status'] as String? ?? 'pending'),
          orElse: () => InstallmentRecordStatus.pending,
        ),
      );
}
