import '../../core/constants/app_enums.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
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
    bool manualSyncOnly = false,
  }) async {
    await synchronizedTransaction((txn) async {
      final installmentRows = await txn.query(
        DbConstants.installments,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [installmentId],
        limit: 1,
      );
      if (installmentRows.isEmpty) {
        throw StateError('Installment not found');
      }
      final installment = installmentRows.first;
      if (amount <= 0) {
        throw StateError('Payment amount must be greater than zero.');
      }
      final newPaidAmount =
          (installment['paid_amount'] as num).toDouble() + amount;
      final installmentAmount = (installment['amount'] as num).toDouble();

      final planId = installment['plan_id'] as int;
      final planRows = await txn.query(
        DbConstants.plans,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [planId],
        limit: 1,
      );
      if (planRows.isEmpty) {
        throw StateError('Plan not found');
      }
      final customerId = planRows.first['customer_id'] as int;

      await txn.update(
        DbConstants.installments,
        SyncMetadata.withLocalChange(DbConstants.installments, {
          'paid_amount': newPaidAmount,
          'status': newPaidAmount >= installmentAmount
              ? InstallmentRecordStatus.paid.name
              : InstallmentRecordStatus.partial.name,
          'manual_sync_only': manualSyncOnly ? 1 : 0,
        }),
        where: 'id = ?',
        whereArgs: [installmentId],
      );

      await txn.insert(
        DbConstants.payments,
        SyncMetadata.withLocalChange(DbConstants.payments, {
          'customer_id': customerId,
          'plan_id': planId,
          'installment_id': installmentId,
          'amount': amount,
          'paid_on': paidOn.toIso8601String(),
          'note': note,
          'manual_sync_only': manualSyncOnly ? 1 : 0,
        }),
      );
    });
  }
}
