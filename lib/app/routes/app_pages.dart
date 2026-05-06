import 'package:get/get.dart';

import '../../modules/customers/customer_detail_view.dart';
import '../../modules/customers/customer_form_view.dart';
import '../../modules/customers/customer_list_view.dart';
import '../../modules/customers/customer_payment_insight_view.dart';
import '../../modules/dashboard/dashboard_view.dart';
import '../../modules/installments/daily_installment_collection_view.dart';
import '../../modules/installments/installment_schedule_view.dart';
import '../../modules/payments/payment_form_view.dart';
import '../../modules/payments/payment_history_view.dart';
import '../../modules/products/product_detail_view.dart';
import '../../modules/products/product_form_view.dart';
import '../../modules/products/product_list_view.dart';
import '../../modules/reports/report_view.dart';
import '../../modules/settings/settings_view.dart';
import '../bindings/customer_binding.dart';
import '../bindings/dashboard_binding.dart';
import '../bindings/installment_binding.dart';
import '../bindings/payment_binding.dart';
import '../bindings/product_binding.dart';
import '../bindings/report_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.customers,
      page: () => const CustomerListView(),
      binding: CustomerBinding(),
    ),
    GetPage(
      name: AppRoutes.customerForm,
      page: () => const CustomerFormView(),
      binding: CustomerBinding(),
    ),
    GetPage(
      name: AppRoutes.customerDetail,
      page: () => const CustomerDetailView(),
      binding: CustomerBinding(),
    ),
    GetPage(
      name: AppRoutes.customerPaymentInsight,
      page: () => const CustomerPaymentInsightView(),
      binding: CustomerBinding(),
    ),
    GetPage(
      name: AppRoutes.products,
      page: () => const ProductListView(),
      binding: ProductBinding(),
    ),
    GetPage(
      name: AppRoutes.productForm,
      page: () => const ProductFormView(),
      binding: ProductBinding(),
    ),
    GetPage(
      name: AppRoutes.productDetail,
      page: () => const ProductDetailView(),
      binding: ProductBinding(),
    ),
    GetPage(
      name: AppRoutes.installments,
      page: () => const InstallmentScheduleView(),
      binding: InstallmentBinding(),
    ),
    GetPage(
      name: AppRoutes.dailyInstallments,
      page: () => const DailyInstallmentCollectionView(),
      binding: InstallmentBinding(),
    ),
    GetPage(
      name: AppRoutes.payments,
      page: () => const PaymentHistoryView(),
      binding: PaymentBinding(),
    ),
    GetPage(
      name: AppRoutes.paymentForm,
      page: () => const PaymentFormView(),
      binding: PaymentBinding(),
    ),
    GetPage(
      name: AppRoutes.reports,
      page: () => const ReportView(),
      binding: ReportBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
    ),
  ];
}
