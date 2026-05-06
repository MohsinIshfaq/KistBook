import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
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

class InstallmentPlanSummary {
  const InstallmentPlanSummary({
    required this.customer,
    required this.plan,
    required this.product,
    required this.installments,
  });

  final CustomerModel customer;
  final PurchasePlanModel plan;
  final ProductModel? product;
  final List<InstallmentModel> installments;

  double get remainingAmount => installments.fold(
        0,
        (sum, item) => sum + item.remainingAmount.clamp(0, double.infinity),
      );

  double get collectedAmount =>
      (plan.totalAmount - remainingAmount).clamp(0, double.infinity);

  int get remainingInstallments =>
      installments.where((item) => !item.isPaid).length;

  InstallmentModel? get nextInstallment =>
      installments.isEmpty ? null : installments.first;

  DateTime? get nextDueDate => nextInstallment?.currentDueDate;

  InstallmentVisualStatus get status {
    final next = nextInstallment;
    if (next == null) {
      return InstallmentVisualStatus.paid;
    }
    return next.visualStatus(DateTime.now());
  }
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

class CustomerPaymentInsight {
  const CustomerPaymentInsight({
    required this.customerId,
    required this.onTimePercentage,
    required this.onTimeInstallments,
    required this.lateInstallments,
    required this.maturedInstallments,
    required this.activePlans,
    required this.completedPlans,
    required this.currentPlanStatus,
    required this.lastPaymentDate,
  });

  final int customerId;
  final double onTimePercentage;
  final int onTimeInstallments;
  final int lateInstallments;
  final int maturedInstallments;
  final int activePlans;
  final int completedPlans;
  final String currentPlanStatus;
  final DateTime? lastPaymentDate;

  bool get hasHistory =>
      maturedInstallments > 0 ||
      activePlans > 0 ||
      completedPlans > 0 ||
      lastPaymentDate != null;

  String get onTimePercentageLabel => '${onTimePercentage.toStringAsFixed(0)}%';

  String get ratingLabel {
    if (!hasHistory || maturedInstallments == 0) {
      return 'New'.tr;
    }
    if (onTimePercentage >= 90) {
      return 'Excellent'.tr;
    }
    if (onTimePercentage >= 75) {
      return 'Good'.tr;
    }
    if (onTimePercentage >= 50) {
      return 'Average'.tr;
    }
    return 'Risky'.tr;
  }

  String get planSummaryLabel {
    if (activePlans > 0) {
      return '@count running'.trParams({'count': '$activePlans'});
    }
    if (completedPlans > 0) {
      return '@count completed'.trParams({'count': '$completedPlans'});
    }
    return 'No previous plan'.tr;
  }
}
