import 'package:get/get.dart';

import '../../data/database/db_helper.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';
import '../../modules/settings/settings_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DbHelper(), permanent: true);
    Get.put(CustomerRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(ProductRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(InstallmentRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(PaymentRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(DashboardRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(ReportRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(NotificationService(), permanent: true);
    Get.find<SettingsController>().load();
    Get.put(
      BackgroundService(
        reportRepository: Get.find<ReportRepository>(),
        notificationService: Get.find<NotificationService>(),
      ),
      permanent: true,
    );
  }
}
