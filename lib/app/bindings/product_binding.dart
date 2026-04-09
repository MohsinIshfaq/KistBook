import 'package:get/get.dart';

import '../../modules/products/product_controller.dart';

class ProductBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ProductController(productRepository: Get.find()));
  }
}
