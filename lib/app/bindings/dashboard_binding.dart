import 'package:get/get.dart';

import '../../modules/dashboard/dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => DashboardController(
        dashboardRepository: Get.find(),
        reportRepository: Get.find(),
      ),
    );
  }
}
