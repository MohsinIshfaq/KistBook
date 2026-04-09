import '../../core/utils/currency_helper.dart';
import 'customer_model.dart';
import 'installment_model.dart';
import 'payment_record_model.dart';
import 'product_model.dart';
import 'purchase_plan_model.dart';

class DueInstallmentDetail {
  const DueInstallmentDetail({
    required this.customer,
    required this.plan,
    required this.installment,
    this.product,
  });

  final CustomerModel customer;
  final PurchasePlanModel plan;
  final InstallmentModel installment;
  final ProductModel? product;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.customers,
    required this.products,
    required this.plans,
    required this.installments,
    required this.payments,
    required this.dueToday,
    required this.overdue,
    required this.pending,
  });

  final List<CustomerModel> customers;
  final List<ProductModel> products;
  final List<PurchasePlanModel> plans;
  final List<InstallmentModel> installments;
  final List<PaymentRecordModel> payments;
  final List<DueInstallmentDetail> dueToday;
  final List<DueInstallmentDetail> overdue;
  final List<DueInstallmentDetail> pending;

  double get totalOutstanding =>
      installments.fold(0, (sum, item) => sum + item.remainingAmount.clamp(0, double.infinity));

  double get totalCollected => payments.fold(0, (sum, item) => sum + item.amount);

  String get totalOutstandingLabel => CurrencyHelper.pkr.format(totalOutstanding);
  String get totalCollectedLabel => CurrencyHelper.pkr.format(totalCollected);
}

class CustomerHistoryEntry {
  const CustomerHistoryEntry({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.isCredit,
  });

  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final bool isCredit;
}

class CustomerProfile {
  const CustomerProfile({
    required this.customer,
    required this.plans,
    required this.installments,
    required this.payments,
    required this.history,
  });

  final CustomerModel customer;
  final List<PurchasePlanModel> plans;
  final List<InstallmentModel> installments;
  final List<PaymentRecordModel> payments;
  final List<CustomerHistoryEntry> history;
}
