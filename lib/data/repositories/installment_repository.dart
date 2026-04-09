import 'dart:math';

import '../../core/constants/app_enums.dart';
import '../../core/utils/date_helper.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/dashboard_models.dart';
import '../models/installment_model.dart';
import '../models/product_model.dart';
import '../models/purchase_plan_model.dart';
import 'generic_repository.dart';

class InstallmentRepository extends GenericRepository<InstallmentModel> {
  InstallmentRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.installments,
          fromMap: InstallmentModel.fromMap,
        );

  Future<void> createPlan(PurchasePlanModel plan) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final planId = await txn.insert(DbConstants.plans, plan.toMap()..remove('id'));
      final financedAmount = max(0.0, plan.totalAmount - plan.depositAmount);

      for (var index = 0; index < plan.installmentCount; index++) {
        final dueDate = DateHelper.shiftFridayToSaturday(
          DateHelper.startOfDay(plan.startDate)
              .add(Duration(days: index * plan.frequencyDays)),
        );
        final remainingAfterPrevious = financedAmount - (index * plan.installmentAmount);
        final amount = min(plan.installmentAmount, remainingAfterPrevious);
        await txn.insert(DbConstants.installments, {
          'plan_id': planId,
          'sequence_number': index + 1,
          'scheduled_due_date': dueDate.toIso8601String(),
          'current_due_date': dueDate.toIso8601String(),
          'amount': amount,
          'paid_amount': 0.0,
          'status': InstallmentRecordStatus.pending.name,
        });
      }
    });
  }

  Future<void> reconcileInstallments({DateTime? today}) async {
    final db = await super.db;
    final effectiveToday = DateHelper.startOfDay(today ?? DateTime.now());
    final rows = await db.query(DbConstants.installments);
    for (final row in rows) {
      final installment = InstallmentModel.fromMap(row);
      if (installment.isPaid) {
        continue;
      }
      final normalizedDue = DateHelper.shiftFridayToSaturday(installment.currentDueDate);
      if (!normalizedDue.isBefore(effectiveToday)) {
        continue;
      }
      final carriedDate = DateHelper.reconcileMissedDueDate(
        currentDueDate: normalizedDue,
        today: effectiveToday,
      );
      await db.update(
        DbConstants.installments,
        {
          'current_due_date': carriedDate.toIso8601String(),
          'status': InstallmentRecordStatus.missed.name,
        },
        where: 'id = ?',
        whereArgs: [installment.id],
      );
    }
  }

  Future<List<DueInstallmentDetail>> fetchActiveInstallments({DateTime? today}) async {
    final db = await super.db;
    final effectiveToday = DateHelper.startOfDay(today ?? DateTime.now());
    await reconcileInstallments(today: effectiveToday);

    final customerRows = await db.query(DbConstants.customers);
    final productRows = await db.query(DbConstants.products);
    final planRows = await db.query(DbConstants.plans);
    final installmentRows = await db.query(
      DbConstants.installments,
      orderBy: 'current_due_date ASC, sequence_number ASC',
    );

    final customers = {
      for (final row in customerRows) (row['id'] as int): CustomerModel.fromMap(row),
    };
    final products = {
      for (final row in productRows) (row['id'] as int): ProductModel.fromMap(row),
    };
    final plans = {
      for (final row in planRows) (row['id'] as int): PurchasePlanModel.fromMap(row),
    };

    final details = <DueInstallmentDetail>[];
    for (final row in installmentRows) {
      final installment = InstallmentModel.fromMap(row);
      if (installment.isPaid) {
        continue;
      }
      final plan = plans[installment.planId];
      if (plan == null) {
        continue;
      }
      final customer = customers[plan.customerId];
      if (customer == null) {
        continue;
      }
      details.add(
        DueInstallmentDetail(
          customer: customer,
          plan: plan,
          installment: installment,
          product: plan.productId == null ? null : products[plan.productId!],
        ),
      );
    }
    return details;
  }
}
