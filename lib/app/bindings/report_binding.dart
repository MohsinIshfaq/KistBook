import 'package:get/get.dart';

import '../../modules/reports/report_controller.dart';

class ReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ReportController(
        reportRepository: Get.find(),
        accessControlService: Get.find(),
      ),
    );
  }
}
