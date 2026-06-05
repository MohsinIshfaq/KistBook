import 'package:get/get.dart';

import '../../data/datasources/access_assignment_remote_data_source.dart';
import '../../modules/users/user_controller.dart';

class UserBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AccessAssignmentRemoteDataSource(Get.find()));
    Get.lazyPut(
      () => UserController(
        userRepository: Get.find(),
        customerRepository: Get.find(),
        installmentRepository: Get.find(),
        authApiService: Get.find(),
        accessAssignmentRemoteDataSource: Get.find(),
      ),
    );
  }
}
