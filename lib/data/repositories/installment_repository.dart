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
          product: plan.primaryProductId == null ? null : products[plan.primaryProductId!],
        ),
      );
    }
    return details;
  }

  Future<InstallmentPlanSummary?> fetchPlanSummary(int planId) async {
    final db = await super.db;
    await reconcileInstallments();

    final planRow = await db.query(
      DbConstants.plans,
      where: 'id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    if (planRow.isEmpty) {
      return null;
    }

    final plan = PurchasePlanModel.fromMap(planRow.first);
    final customerRow = await db.query(
      DbConstants.customers,
      where: 'id = ?',
      whereArgs: [plan.customerId],
      limit: 1,
    );
    if (customerRow.isEmpty) {
      return null;
    }

    final installmentRows = await db.query(
      DbConstants.installments,
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'current_due_date ASC, sequence_number ASC',
    );
    final installments = installmentRows.map(InstallmentModel.fromMap).toList();

    ProductModel? product;
    if (plan.primaryProductId != null) {
      final productRow = await db.query(
        DbConstants.products,
        where: 'id = ?',
        whereArgs: [plan.primaryProductId],
        limit: 1,
      );
      if (productRow.isNotEmpty) {
        product = ProductModel.fromMap(productRow.first);
      }
    }

    return InstallmentPlanSummary(
      customer: CustomerModel.fromMap(customerRow.first),
      plan: plan,
      product: product,
      installments: installments,
    );
  }

  Future<void> updatePlanConfiguration(PurchasePlanModel updatedPlan) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        DbConstants.installments,
        where: 'plan_id = ?',
        whereArgs: [updatedPlan.id],
        orderBy: 'sequence_number ASC',
      );
      final installments = existingRows.map(InstallmentModel.fromMap).toList();
      final paidInstallments = installments.where((item) => item.paidAmount > 0).toList();
      final unpaidInstallments = installments.where((item) => item.paidAmount <= 0).toList();
      final paidAmount = installments.fold<double>(0, (sum, item) => sum + item.paidAmount);

      await txn.update(
        DbConstants.plans,
        updatedPlan.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [updatedPlan.id],
      );

      for (final installment in unpaidInstallments) {
        await txn.delete(
          DbConstants.installments,
          where: 'id = ?',
          whereArgs: [installment.id],
        );
      }

      final financedAmount = max(0.0, updatedPlan.totalAmount - updatedPlan.depositAmount);
      var remainingAmount = max(0.0, financedAmount - paidAmount);
      var sequence = paidInstallments.length + 1;
      var dueDate = DateHelper.startOfDay(updatedPlan.startDate);

      while (remainingAmount > 0.009 && updatedPlan.installmentAmount > 0) {
        final shiftedDueDate = DateHelper.shiftFridayToSaturday(dueDate);
        final amount = min(updatedPlan.installmentAmount, remainingAmount);
        await txn.insert(DbConstants.installments, {
          'plan_id': updatedPlan.id,
          'sequence_number': sequence,
          'scheduled_due_date': shiftedDueDate.toIso8601String(),
          'current_due_date': shiftedDueDate.toIso8601String(),
          'amount': amount,
          'paid_amount': 0.0,
          'status': InstallmentRecordStatus.pending.name,
        });
        remainingAmount -= amount;
        sequence += 1;
        dueDate = dueDate.add(Duration(days: updatedPlan.frequencyDays));
      }
    });
  }

  Future<void> rescheduleNextInstallment({
    required int planId,
    required DateTime targetDate,
  }) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        DbConstants.installments,
        where: 'plan_id = ? AND paid_amount < amount',
        whereArgs: [planId],
        orderBy: 'sequence_number ASC',
        limit: 1,
      );

      if (rows.isEmpty) {
        return;
      }

      final installment = InstallmentModel.fromMap(rows.first);
      final shiftedDate = DateHelper.shiftFridayToSaturday(
        DateHelper.startOfDay(targetDate),
      );

      await txn.update(
        DbConstants.installments,
        {
          'scheduled_due_date': shiftedDate.toIso8601String(),
          'current_due_date': shiftedDate.toIso8601String(),
          'status': InstallmentRecordStatus.pending.name,
        },
        where: 'id = ?',
        whereArgs: [installment.id],
      );
    });
  }

  Future<void> rescheduleInstallment({
    required int installmentId,
    required DateTime targetDate,
  }) async {
    final db = await super.db;
    final shiftedDate = DateHelper.shiftFridayToSaturday(
      DateHelper.startOfDay(targetDate),
    );
    await db.update(
      DbConstants.installments,
      {
        'scheduled_due_date': shiftedDate.toIso8601String(),
        'current_due_date': shiftedDate.toIso8601String(),
        'status': InstallmentRecordStatus.pending.name,
      },
      where: 'id = ?',
      whereArgs: [installmentId],
    );
  }
}
