import 'package:get/get.dart';

import '../../modules/users/user_controller.dart';

class UserBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => UserController(
        userRepository: Get.find(),
        customerRepository: Get.find(),
        installmentRepository: Get.find(),
        authApiService: Get.find(),
      ),
    );
  }
}
