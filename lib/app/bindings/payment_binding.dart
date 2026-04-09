import 'package:get/get.dart';

import '../../modules/payments/payment_controller.dart';

class PaymentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => PaymentController(
        paymentRepository: Get.find(),
        installmentRepository: Get.find(),
      ),
    );
  }
}
