import '../../data/database/db_constants.dart';
import '../../data/database/db_helper.dart';
import '../../data/database/sync_metadata.dart';
import '../../core/utils/date_helper.dart';
import '../../core/constants/app_enums.dart';
import '../models/customer_model.dart';
import '../models/dashboard_models.dart';
import '../models/installment_model.dart';
import '../models/payment_record_model.dart';
import '../models/product_model.dart';
import '../models/purchase_plan_model.dart';
import 'generic_repository.dart';
import 'sql_expression.dart';

class CustomerRepository extends GenericRepository<CustomerModel> {
  CustomerRepository(DbHelper dbHelper)
    : super(
        dbHelper: dbHelper,
        tableName: DbConstants.customers,
        fromMap: CustomerModel.fromMap,
      );

  Future<List<CustomerModel>> fetchCustomers() async {
    return getAll(orderBy: 'created_at DESC');
  }

  Future<CustomerModel> saveCustomer(CustomerModel customer) async {
    final saved = await save(customer);
    return saved.id == customer.id ? saved : customer.copyWith(id: saved.id);
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final planRows = await txn.query(
        DbConstants.plans,
        columns: ['id'],
        where: 'customer_id = ? AND is_deleted = 0',
        whereArgs: [customerId],
      );
      for (final row in planRows) {
        final planId = row['id'] as int;
        await txn.update(
          DbConstants.payments,
          SyncMetadata.withLocalChange(DbConstants.payments, {'is_deleted': 1}),
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
        await txn.update(
          DbConstants.installments,
          SyncMetadata.withLocalChange(DbConstants.installments, {
            'is_deleted': 1,
          }),
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
      }
      await txn.update(
        DbConstants.plans,
        SyncMetadata.withLocalChange(DbConstants.plans, {'is_deleted': 1}),
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      await txn.update(
        DbConstants.customers,
        SyncMetadata.withLocalChange(DbConstants.customers, {'is_deleted': 1}),
        where: 'id = ?',
        whereArgs: [customerId],
      );
    });
  }

  Future<String?> serverIdForCustomer(int customerId) async {
    final db = await super.db;
    final rows = await db.query(
      DbConstants.customers,
      columns: [SyncMetadata.serverId],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [customerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final value = rows.first[SyncMetadata.serverId]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<CustomerProfile?> fetchCustomerProfile(int customerId) async {
    final customer = await findOne(customerId);
    if (customer == null) {
      return null;
    }

    final db = await super.db;
    final plans = (await db.query(
      DbConstants.plans,
      where:
          '${SQLCondition('customer_id', '=', customerId).buildQuery()} AND is_deleted = 0',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    )).map(PurchasePlanModel.fromMap).toList();
    final productIds = plans.expand((plan) => plan.productIds).toSet();
    final products = <ProductModel>[];
    if (productIds.isNotEmpty) {
      final placeholders = List.filled(productIds.length, '?').join(',');
      products.addAll(
        (await db.query(
          DbConstants.products,
          where: 'id IN ($placeholders) AND is_deleted = 0',
          whereArgs: productIds.toList(),
        )).map(ProductModel.fromMap),
      );
    }
    final payments = (await db.query(
      DbConstants.payments,
      where:
          '${SQLCondition('customer_id', '=', customerId).buildQuery()} AND is_deleted = 0',
      whereArgs: [customerId],
      orderBy: 'paid_on DESC',
    )).map(PaymentRecordModel.fromMap).toList();
    final installments = <InstallmentModel>[];
    final history = <CustomerHistoryEntry>[];

    for (final plan in plans) {
      final rows = await db.query(
        DbConstants.installments,
        where: 'plan_id = ? AND is_deleted = 0',
        whereArgs: [plan.id],
        orderBy: 'sequence_number ASC',
      );
      final planInstallments = rows.map(InstallmentModel.fromMap).toList();
      installments.addAll(planInstallments);
      history.add(
        CustomerHistoryEntry(
          title: 'Purchase created',
          subtitle: plan.itemName,
          amount: plan.totalAmount,
          date: plan.createdAt,
          isCredit: false,
          status: CustomerHistoryStatus.pending,
          planId: plan.id,
          productIds: plan.productIds,
        ),
      );
      if (plan.depositAmount > 0) {
        history.add(
          CustomerHistoryEntry(
            title: 'Advance received',
            subtitle: plan.itemName,
            amount: plan.depositAmount,
            date: plan.createdAt,
            isCredit: true,
            status: CustomerHistoryStatus.paid,
            planId: plan.id,
            productIds: plan.productIds,
          ),
        );
      }
      for (final installment in planInstallments) {
        if (installment.isPaid) {
          continue;
        }
        history.add(
          CustomerHistoryEntry(
            title: 'Pending installment',
            subtitle:
                '${plan.itemName} • Installment #${installment.sequenceNumber}',
            amount: installment.remainingAmount,
            date: installment.currentDueDate,
            isCredit: false,
            status: CustomerHistoryStatus.pending,
            planId: plan.id,
            productIds: plan.productIds,
          ),
        );
      }
    }

    final productIdsByPlanId = {
      for (final plan in plans)
        if (plan.id != null) plan.id!: plan.productIds,
    };
    for (final payment in payments) {
      history.add(
        CustomerHistoryEntry(
          title: 'Installment payment',
          subtitle: payment.note.isEmpty ? 'Manual entry' : payment.note,
          amount: payment.amount,
          date: payment.paidOn,
          isCredit: true,
          status: CustomerHistoryStatus.paid,
          planId: payment.planId,
          productIds: productIdsByPlanId[payment.planId] ?? const [],
        ),
      );
    }

    history.sort((a, b) => b.date.compareTo(a.date));

    return CustomerProfile(
      customer: customer,
      plans: plans,
      products: products,
      installments: installments,
      payments: payments,
      history: history,
    );
  }

  Future<Map<int, CustomerPaymentInsight>>
  fetchCustomerPaymentInsights() async {
    final db = await super.db;
    final customers = await fetchCustomers();
    final plans = (await db.query(
      DbConstants.plans,
      where: 'is_deleted = 0',
    )).map(PurchasePlanModel.fromMap).toList();
    final installments = (await db.query(
      DbConstants.installments,
      where: 'is_deleted = 0',
    )).map(InstallmentModel.fromMap).toList();
    final payments = (await db.query(
      DbConstants.payments,
      where: 'is_deleted = 0',
    )).map(PaymentRecordModel.fromMap).toList();
    final today = DateHelper.startOfDay(DateTime.now());

    final paymentsByInstallment = <int, List<PaymentRecordModel>>{};
    for (final payment in payments) {
      paymentsByInstallment
          .putIfAbsent(payment.installmentId, () => [])
          .add(payment);
    }
    for (final item in paymentsByInstallment.values) {
      item.sort((a, b) => a.paidOn.compareTo(b.paidOn));
    }

    return {
      for (final customer in customers)
        if (customer.id != null)
          customer.id!: _buildInsight(
            customerId: customer.id!,
            plans: plans
                .where((plan) => plan.customerId == customer.id)
                .toList(),
            installments: installments,
            paymentsByInstallment: paymentsByInstallment,
            today: today,
          ),
    };
  }

  CustomerPaymentInsight _buildInsight({
    required int customerId,
    required List<PurchasePlanModel> plans,
    required List<InstallmentModel> installments,
    required Map<int, List<PaymentRecordModel>> paymentsByInstallment,
    required DateTime today,
  }) {
    final planIds = plans.map((item) => item.id).whereType<int>().toSet();
    final relevantInstallments =
        installments.where((item) => planIds.contains(item.planId)).toList()
          ..sort((a, b) => a.currentDueDate.compareTo(b.currentDueDate));

    var maturedInstallments = 0;
    var onTimeInstallments = 0;
    var lateInstallments = 0;
    DateTime? lastPaymentDate;

    for (final installment in relevantInstallments) {
      final paymentTrail =
          paymentsByInstallment[installment.id ?? -1] ?? const [];
      if (paymentTrail.isNotEmpty) {
        final latest = paymentTrail.last.paidOn;
        if (lastPaymentDate == null || latest.isAfter(lastPaymentDate)) {
          lastPaymentDate = latest;
        }
      }

      final dueDate = DateHelper.startOfDay(installment.currentDueDate);
      final isMatured = !dueDate.isAfter(today);
      if (!isMatured) {
        continue;
      }

      maturedInstallments += 1;
      final paidDate = _paidInFullDate(installment, paymentTrail);
      final isOnTime =
          paidDate != null && !DateHelper.startOfDay(paidDate).isAfter(dueDate);
      if (isOnTime) {
        onTimeInstallments += 1;
        continue;
      }

      if (installment.status == InstallmentRecordStatus.missed ||
          installment.status == InstallmentRecordStatus.overdue ||
          (paidDate != null &&
              DateHelper.startOfDay(paidDate).isAfter(dueDate)) ||
          (paidDate == null && dueDate.isBefore(today)) ||
          (paidDate == null && dueDate.isAtSameMomentAs(today))) {
        lateInstallments += 1;
      }
    }

    var activePlans = 0;
    var completedPlans = 0;
    for (final plan in plans) {
      final planInstallments = relevantInstallments
          .where((item) => item.planId == plan.id)
          .toList();
      if (planInstallments.isEmpty) {
        continue;
      }
      final hasPending = planInstallments.any((item) => !item.isPaid);
      if (hasPending) {
        activePlans += 1;
      } else {
        completedPlans += 1;
      }
    }

    final latestPlan = plans.isEmpty
        ? null
        : (plans.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              .first;
    final latestPlanInstallments = latestPlan == null
        ? const <InstallmentModel>[]
        : relevantInstallments
              .where((item) => item.planId == latestPlan.id)
              .toList();
    final currentPlanStatus = latestPlan == null
        ? 'No previous plan'
        : latestPlanInstallments.any((item) => !item.isPaid)
        ? 'Running plan'
        : 'Completed plan';
    final onTimePercentage = maturedInstallments == 0
        ? 0.0
        : (onTimeInstallments / maturedInstallments) * 100;

    return CustomerPaymentInsight(
      customerId: customerId,
      onTimePercentage: onTimePercentage,
      onTimeInstallments: onTimeInstallments,
      lateInstallments: lateInstallments,
      maturedInstallments: maturedInstallments,
      activePlans: activePlans,
      completedPlans: completedPlans,
      currentPlanStatus: currentPlanStatus,
      lastPaymentDate: lastPaymentDate,
    );
  }

  DateTime? _paidInFullDate(
    InstallmentModel installment,
    List<PaymentRecordModel> payments,
  ) {
    if (payments.isEmpty) {
      return installment.isPaid ? installment.currentDueDate : null;
    }

    var runningTotal = 0.0;
    for (final payment in payments) {
      runningTotal += payment.amount;
      if (runningTotal + 0.009 >= installment.amount) {
        return payment.paidOn;
      }
    }
    return installment.isPaid ? payments.last.paidOn : null;
  }
}
