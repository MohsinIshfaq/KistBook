import 'package:get/get.dart';

import '../../modules/installments/installment_controller.dart';

class InstallmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => InstallmentController(
        installmentRepository: Get.find(),
        customerRepository: Get.find(),
        productRepository: Get.find(),
        accessControlService: Get.find(),
      ),
    );
  }
}
