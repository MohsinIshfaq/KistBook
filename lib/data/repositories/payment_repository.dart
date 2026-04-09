import '../../core/constants/app_enums.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/payment_record_model.dart';
import 'generic_repository.dart';

class PaymentRepository extends GenericRepository<PaymentRecordModel> {
  PaymentRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.payments,
          fromMap: PaymentRecordModel.fromMap,
        );

  Future<List<PaymentRecordModel>> fetchPayments() async {
    return getAll(orderBy: 'paid_on DESC');
  }

  Future<void> addPayment({
    required int installmentId,
    required double amount,
    required DateTime paidOn,
    required String note,
  }) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final installmentRows = await txn.query(
        DbConstants.installments,
        where: 'id = ?',
        whereArgs: [installmentId],
        limit: 1,
      );
      if (installmentRows.isEmpty) {
        throw StateError('Installment not found');
      }
      final installment = installmentRows.first;
      final remaining =
          (installment['amount'] as num).toDouble() - (installment['paid_amount'] as num).toDouble();
      final normalizedAmount = amount.clamp(0, remaining).toDouble();
      final newPaidAmount =
          (installment['paid_amount'] as num).toDouble() + normalizedAmount;

      final planId = installment['plan_id'] as int;
      final planRows = await txn.query(
        DbConstants.plans,
        where: 'id = ?',
        whereArgs: [planId],
        limit: 1,
      );
      final customerId = planRows.first['customer_id'] as int;

      await txn.update(
        DbConstants.installments,
        {
          'paid_amount': newPaidAmount,
          'status': newPaidAmount >= (installment['amount'] as num).toDouble()
              ? InstallmentRecordStatus.paid.name
              : installment['status'],
        },
        where: 'id = ?',
        whereArgs: [installmentId],
      );

      await txn.insert(DbConstants.payments, {
        'customer_id': customerId,
        'plan_id': planId,
        'installment_id': installmentId,
        'amount': normalizedAmount,
        'paid_on': paidOn.toIso8601String(),
        'note': note,
      });
    });
  }
}
