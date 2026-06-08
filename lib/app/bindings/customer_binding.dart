import 'package:get/get.dart';

import '../../modules/customers/customer_controller.dart';

class CustomerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CustomerController(
        customerRepository: Get.find(),
        installmentRepository: Get.find(),
        accessControlService: Get.find(),
        planRefreshRepository: Get.find(),
      ),
    );
  }
}
