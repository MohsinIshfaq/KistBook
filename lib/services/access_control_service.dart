import '../core/constants/app_enums.dart';
import '../data/models/customer_model.dart';
import '../data/models/dashboard_models.dart';
import '../data/models/payment_record_model.dart';
import '../data/models/purchase_plan_model.dart';
import '../data/database/db_constants.dart';
import '../data/database/db_helper.dart';
import '../data/repositories/customer_user_access_repository.dart';
import '../data/repositories/plan_user_access_repository.dart';
import 'session_manager.dart';

class AccessControlService {
  AccessControlService({
    required SessionManager sessionManager,
    required CustomerUserAccessRepository customerAccessRepository,
    required PlanUserAccessRepository planAccessRepository,
    required DbHelper dbHelper,
  })  : _sessionManager = sessionManager,
        _customerAccessRepository = customerAccessRepository,
        _planAccessRepository = planAccessRepository,
        _dbHelper = dbHelper;

  final SessionManager _sessionManager;
  final CustomerUserAccessRepository _customerAccessRepository;
  final PlanUserAccessRepository _planAccessRepository;
  final DbHelper _dbHelper;

  bool get hasFullAccess => _sessionManager.role == UserRole.owner;

  Future<Set<int>> allowedCustomerIds() async {
    if (hasFullAccess || _sessionManager.userUuid.isEmpty) {
      return <int>{};
    }
    final rows = await _customerAccessRepository.fetchForUser(_sessionManager.userUuid);
    return rows.map((item) => int.tryParse(item.customerUuid)).whereType<int>().toSet();
  }

  Future<Set<int>> allowedPlanIds() async {
    if (hasFullAccess || _sessionManager.userUuid.isEmpty) {
      return <int>{};
    }
    final rows = await _planAccessRepository.fetchForUser(_sessionManager.userUuid);
    return rows.map((item) => int.tryParse(item.planUuid)).whereType<int>().toSet();
  }

  Future<List<CustomerModel>> filterCustomers(List<CustomerModel> customers) async {
    if (hasFullAccess) {
      return customers;
    }
    final customerIds = await _effectiveAllowedCustomerIds();
    return customers.where((item) => item.id != null && customerIds.contains(item.id)).toList();
  }

  Future<List<DueInstallmentDetail>> filterDueInstallments(
    List<DueInstallmentDetail> items,
  ) async {
    if (hasFullAccess) {
      return items;
    }
    final customerIds = await allowedCustomerIds();
    final planIds = await allowedPlanIds();
    return items.where((item) {
      final customerId = item.customer.id;
      final planId = item.plan.id;
      if (customerId != null && customerIds.contains(customerId)) {
        return true;
      }
      return planId != null && planIds.contains(planId);
    }).toList();
  }

  Future<List<PaymentRecordModel>> filterPayments(List<PaymentRecordModel> items) async {
    if (hasFullAccess) {
      return items;
    }
    final customerIds = await allowedCustomerIds();
    final planIds = await allowedPlanIds();
    return items.where((item) {
      if (customerIds.contains(item.customerId)) {
        return true;
      }
      return planIds.contains(item.planId);
    }).toList();
  }

  Future<DashboardSnapshot> filterSnapshot(DashboardSnapshot snapshot) async {
    if (hasFullAccess) {
      return snapshot;
    }
    final customerIds = await allowedCustomerIds();
    final planIds = await allowedPlanIds();

    bool allowPlan(PurchasePlanModel plan) {
      if (customerIds.contains(plan.customerId)) {
        return true;
      }
      return plan.id != null && planIds.contains(plan.id);
    }

    final allowedPlans = snapshot.plans.where(allowPlan).toList();
    final visiblePlanIds = allowedPlans.map((item) => item.id).whereType<int>().toSet();
    final visibleCustomerIds = <int>{
      ...customerIds,
      ...allowedPlans.map((item) => item.customerId),
    };
    final customers = snapshot.customers
        .where((item) => item.id != null && visibleCustomerIds.contains(item.id))
        .toList();
    final installments = snapshot.installments
        .where((item) => visiblePlanIds.contains(item.planId))
        .toList();
    final payments = snapshot.payments
        .where((item) => visiblePlanIds.contains(item.planId) || visibleCustomerIds.contains(item.customerId))
        .toList();
    final productIds = allowedPlans.expand((item) => item.productIds).toSet();
    final products = snapshot.products
        .where((item) => item.id != null && productIds.contains(item.id))
        .toList();
    final dueToday = snapshot.dueToday
        .where((item) => item.plan.id != null && visiblePlanIds.contains(item.plan.id))
        .toList();
    final overdue = snapshot.overdue
        .where((item) => item.plan.id != null && visiblePlanIds.contains(item.plan.id))
        .toList();
    final pending = snapshot.pending
        .where((item) => item.plan.id != null && visiblePlanIds.contains(item.plan.id))
        .toList();

    return DashboardSnapshot(
      customers: customers,
      products: products,
      plans: allowedPlans,
      installments: installments,
      payments: payments,
      dueToday: dueToday,
      overdue: overdue,
      pending: pending,
    );
  }

  Future<Set<int>> _effectiveAllowedCustomerIds() async {
    final customerIds = await allowedCustomerIds();
    final planIds = await allowedPlanIds();
    if (planIds.isEmpty) {
      return customerIds;
    }
    final database = await _dbHelper.database;
    final rows = await database.query(DbConstants.plans);
    final plans = rows.map(PurchasePlanModel.fromMap);
    return {
      ...customerIds,
      ...plans.where((item) => item.id != null && planIds.contains(item.id)).map((item) => item.customerId),
    };
  }
}
