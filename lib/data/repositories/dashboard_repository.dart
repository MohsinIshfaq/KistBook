import '../../core/constants/app_enums.dart';
import '../../core/utils/date_helper.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/dashboard_models.dart';
import '../models/installment_model.dart';
import '../models/payment_record_model.dart';
import '../models/product_model.dart';
import '../models/purchase_plan_model.dart';
import 'installment_repository.dart';

class DashboardRepository {
  DashboardRepository(this._dbHelper);

  final DbHelper _dbHelper;

  Future<DashboardSnapshot> fetchSnapshot({DateTime? today}) async {
    final db = await _dbHelper.database;
    final installmentRepository = InstallmentRepository(_dbHelper);
    final effectiveToday = DateHelper.startOfDay(today ?? DateTime.now());
    await installmentRepository.reconcileInstallments(today: effectiveToday);

    final customers =
        (await db.query(DbConstants.customers, orderBy: 'created_at DESC'))
            .map(CustomerModel.fromMap)
            .toList();
    final products =
        (await db.query(DbConstants.products, orderBy: 'created_at DESC'))
            .map(ProductModel.fromMap)
            .toList();
    final plans = (await db.query(DbConstants.plans, orderBy: 'created_at DESC'))
        .map(PurchasePlanModel.fromMap)
        .toList();
    final installments = (await db.query(
      DbConstants.installments,
      orderBy: 'current_due_date ASC, sequence_number ASC',
    ))
        .map(InstallmentModel.fromMap)
        .toList();
    final payments = (await db.query(DbConstants.payments, orderBy: 'paid_on DESC'))
        .map(PaymentRecordModel.fromMap)
        .toList();

    final customerById = {for (final item in customers) item.id!: item};
    final planById = {for (final item in plans) item.id!: item};
    final productById = {for (final item in products) item.id!: item};

    final dueToday = <DueInstallmentDetail>[];
    final overdue = <DueInstallmentDetail>[];
    final pending = <DueInstallmentDetail>[];

    for (final installment in installments) {
      if (installment.isPaid) {
        continue;
      }
      final plan = planById[installment.planId];
      if (plan == null) {
        continue;
      }
      final customer = customerById[plan.customerId];
      if (customer == null) {
        continue;
      }
      final detail = DueInstallmentDetail(
        customer: customer,
        plan: plan,
        installment: installment,
        product: plan.primaryProductId == null ? null : productById[plan.primaryProductId!],
      );
      if (DateHelper.startOfDay(installment.currentDueDate) == effectiveToday) {
        dueToday.add(detail);
      }
      if (installment.visualStatus(effectiveToday) == InstallmentVisualStatus.overdue) {
        overdue.add(detail);
      } else {
        pending.add(detail);
      }
    }

    return DashboardSnapshot(
      customers: customers,
      products: products,
      plans: plans,
      installments: installments,
      payments: payments,
      dueToday: dueToday,
      overdue: overdue,
      pending: pending,
    );
  }
}
