import 'package:get/get.dart';

import '../../data/models/product_model.dart';
import '../../data/models/product_price_history_model.dart';
import '../../data/repositories/product_repository.dart';

class ProductController extends GetxController {
  ProductController({required ProductRepository productRepository})
      : _productRepository = productRepository;

  final ProductRepository _productRepository;

  List<ProductModel> products = [];
  ProductModel? product;
  List<ProductPriceHistoryModel> priceHistory = [];
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  Future<void> loadProducts() async {
    isLoading = true;
    update();
    products = await _productRepository.fetchProducts();
    isLoading = false;
    update();
  }

  Future<void> saveProduct(ProductModel product) async {
    await _productRepository.saveProduct(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int productId) async {
    await _productRepository.deleteProduct(productId);
    await loadProducts();
  }

  Future<void> loadProduct(int productId) async {
    isLoading = true;
    update();
    product = await _productRepository.fetchProduct(productId);
    priceHistory = await _productRepository.fetchPriceHistory(productId);
    isLoading = false;
    update();
  }
}
